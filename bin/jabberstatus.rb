# Copyright (c) 2008 James Smith (www.floppy.org.uk)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# http://www.opensource.org/licenses/mit-license.php

require 'rubygems'
require 'xmpp4r/client'
require 'xmpp4r/roster/helper/roster'
require 'facebooker'
require 'log4r'
require 'yaml'

# Load config file
config = YAML.load_file("#{File.dirname(__FILE__)}/../config/config.yml")
XMPP_JID = config['jabber_id']
XMPP_PASSWORD = config['jabber_password']
FB_API_KEY = config['facebook_api_key']
FB_API_SECRET = config['facebook_api_secret']
ADMIN_JID = config['admin_jid']

# Create logger
@@log = Log4r::Logger.new 'log'
@@log.outputters = Log4r::Outputter.stdout
@@log.level = config['debug_mode'] == true ? Log4r::DEBUG : Log4r::ERROR
Jabber.debug = @@log.debug?

@sessions = {}

module Jabber
  module Roster
    class RosterItem
      def facebook_session=(session)
        @@log.debug "Storing facebook session for #{jid}"
        if session.infinite?
          self.iname = "#{session.session_key} #{session.user.id} #{session.auth_token} #{session.secret_for_method(nil)}"
          @@log.debug " - stored \"#{self.iname}\""
          send
        else
          raise "Facebook session for #{jid} is not infinite!"
        end
      end
      def facebook_session
        @@log.debug "Restoring facebook session for #{jid}"
        session_key, session_uid, session_auth_token, secret_from_session = self.iname.split
        session = Facebooker::Session::Desktop.create( FB_API_KEY, FB_API_SECRET )
        session.auth_token = session_auth_token
        session.secure_with!(session_key, session_uid, 0, secret_from_session)
        return session
      end
    end
  end
end

def unescapeHTML(string)
  string = CGI::unescapeHTML(string)
  # CGI::unescapeHTML doesn't replace &apos, but we need to.
  string.gsub("&apos;", "'")
end

def send_message(to, type, message)
  @@log.debug "sending message to #{to} - '#{message}'"
  m = Jabber::Message::new(to, message)
  m.type = type
  @@client.send(m)
end

def add_new_user(jid)
  @@log.debug "adding new user #{jid.to_s}"
  # Accept subscription
  @@roster.accept_subscription(jid)  
  # Open facebook session
  key = jid.strip.to_s
  @sessions[key] = Facebooker::Session::Desktop.create( FB_API_KEY, FB_API_SECRET )
  # Send welcome messages
  send_message jid, :chat, "Hi there #{jid.node.capitalize}! I can update your Facebook status for you if you like, but I need you to do a couple of things for me in order to do so."
  send_message jid, :chat, "Please go to #{@sessions[key].login_url} and log in. Make sure you check the box which says 'save my login info'."
  send_message jid, :chat, "Then, please go to http://www.facebook.com/authorize.php?api_key=#{FB_API_KEY}&v=1.0&ext_perm=status_update, check the box and click OK."
  send_message jid, :chat, "When you've done those, come back here and let me know (just type OK or something)."
end

def set_status(user, message)
  message = unescapeHTML(message)
  @@log.debug "setting Facebook status for #{user.jid.to_s} to \"#{message}\""
  session = user.facebook_session
  session.user.status = message
  "#{session.user.name} #{session.user.status.message}"
rescue
  "It looks like your Facebook session has expired :("
end

def remove_user(roster_item)
  @@log.debug "removing #{roster_item.jid.to_s} from roster"
  roster_item.remove
  send_message roster_item.jid, :chat, "Goodbye #{roster_item.jid.node.capitalize}, thanks for using this service!"
end

def dump_roster
  @@log.debug "Roster: #{@@roster.items.size} items"
  @@roster.items.each { |jid, item|
    @@log.debug "- #{item.iname} (#{item.jid})"
  }
end

@@log.debug "Creating jabber client"
@@client = Jabber::Client::new(XMPP_JID)
@@client.connect
@@client.auth(XMPP_PASSWORD)
@@log.debug "Authenticated with Jabber server"
@@client.send(Jabber::Presence::new(:chat, 'awaiting your command :)'))
@@log.debug "Presence sent"
# Get the roster
@@roster = Jabber::Roster::Helper.new(@@client)
dump_roster if @@log.debug?

mainthread = Thread.current

# Respond to subscriptions
subscription_callback = lambda { |item,presence|
  name = presence.from
  case presence.type
    when :subscribe then       
      add_new_user(presence.from)
    when :unsubscribe then 
      remove_user(item)
  end
}
@@roster.add_subscription_callback(0, nil, &subscription_callback)
@@roster.add_subscription_request_callback(0, nil, &subscription_callback)

# Respond to messages
@@client.add_message_callback do |m|
  # Get data from message
  @@log.debug "Responding to new message from #{m.from}"
  from_jid = Jabber::JID.new(m.from)
  message = m.body
  # Process
  unless m.type == :error or message.nil?
    @@log.debug "... not an error"
    u = @@roster.find(from_jid.strip)[from_jid.strip]
    dump_roster if @@log.debug?
    if u.nil?
      @@log.debug "... couldn't find user '#{from_jid.strip}' in roster - saying hello"
      send_message(from_jid, m.type, "Hi! I don't think I know you - please add me to your contact list, and I can update your Facebook status for you!")
    elsif m.body == 'exit' and from_jid.strip == ADMIN_JID
      @@log.debug "... exit received"
      send_message(from_jid, m.type, "Exiting...")
      mainthread.wakeup
    else
      @@log.debug "... message is '#{message}'"
      key = from_jid.strip.to_s
      unless @sessions[key].nil?
        @@log.debug "... storing session data in roster"
        begin
          @sessions[key].secure!
          u.facebook_session = @sessions[key]
          @sessions[key] = nil
          @@log.debug "... done"
          send_message(from_jid, m.type, "Thanks! You should now be able to set your status by just sending me a message. For instance, if you send 'is using JabberStatus', I will set your Facebook status to 'Yourname is using JabberStatus'. Try it out!")
        rescue
          send_message(from_jid, m.type, "Oops - something went wrong - we couldn't get the right details from Facebook. Did you check the 'save my login info' box?")
        end
      else 
        new_status = set_status(u, message)
        send_message(from_jid, m.type, "I set your Facebook status to: \"#{new_status}\"")
      end
    end
  end
end

@@log.debug "Ready for commands"
Thread.stop
@@log.debug "Exiting"
@@client.close