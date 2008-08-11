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

dir = File.dirname(__FILE__) + '/../lib'
$LOAD_PATH << dir unless $LOAD_PATH.include?(dir)

require 'rubygems'
require 'xmpp4r/client'
require 'xmpp4r/roster/helper/roster'
require 'log4r'
require 'yaml'

require 'jabberstatus/service_factory'

# Load config file
config = YAML.load_file("#{File.dirname(__FILE__)}/../config/config.yml")
XMPP_JID = config['jabber_id']
XMPP_PASSWORD = config['jabber_password']
TWITTER_CRYPT_KEY = config['twitter_crypt_key']
TWITTER_CRYPT_IV = config['twitter_crypt_iv']
FB_API_KEY = config['facebook_api_key']
FB_API_SECRET = config['facebook_api_secret']
ADMIN_JID = config['admin_jid']

# Create logger
@@log = Log4r::Logger.new 'log'
@@log.outputters = Log4r::Outputter.stdout
@@log.level = config['debug_mode'] == true ? Log4r::DEBUG : Log4r::ERROR
Jabber.debug = @@log.debug?

@sessions = {}

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
  key = jid.strip.to_s
  @sessions ||= {}
  @sessions[key] = @@service.create_session
  response = @@service.welcome_message(@sessions[key], jid)
  response.each { |msg| send_message jid, :chat, msg }
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

@@log.debug "Create service object"
@@service = ServiceFactory.create_service(:log => @@log)

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
      send_message(from_jid, m.type, "Hi! I don't think I know you - please add me to your contact list, and I can update your #{@@service.name} status for you!")
    elsif m.body == 'exit' and from_jid.strip == ADMIN_JID
      @@log.debug "... exit received"
      send_message(from_jid, m.type, "Exiting...")
      mainthread.wakeup
    else
      @@log.debug "... message is '#{message}'"
      key = from_jid.strip.to_s
      unless @sessions[key].nil?
        @@log.debug "... storing session data in roster"
        response = @@service.store_session(u, @sessions[key], message)
        @sessions[key] = nil
      else
        response = @@service.set_status(u, unescapeHTML(message))
      end
      send_message(from_jid, m.type, response)
    end
  end
end

@@log.debug "Ready for commands"
Thread.stop
@@log.debug "Exiting"
@@client.close