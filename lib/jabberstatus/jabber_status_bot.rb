# Copyright (c) 2008 James Smith (www.floppy.org.uk)
#
# http://www.opensource.org/licenses/mit-license.php

require 'rubygems'
require 'xmpp4r/client'
require 'xmpp4r/roster/helper/roster'

require 'jabberstatus/string'
require 'jabberstatus/service_factory'

class JabberStatusBot

  def initialize(options)
    # Create pending session store
    @sessions = {}
    # Store logger
    @log = options[:log]
    # Store handle to main thread
    @mainthread = options[:mainthread]
    # Create service object
    @log.debug "Creating service object"
    @service = ServiceFactory.create_service(options)
    # Create XMPP client
    @log.debug "Creating jabber client"
    @client = Jabber::Client::new(options['jabber_id'] + '/JabberStatus')
    @client.connect
    @client.auth(options['jabber_password'])
    @log.debug "Authenticated with Jabber server"
    @client.send(Jabber::Presence::new(:chat, 'awaiting your command :)'))
    @log.debug "Presence sent"
    # Store admin JID
    @admin_jid = options['admin_jid']
    # Get the roster
    @roster = Jabber::Roster::Helper.new(@client)
    dump_roster if @log.debug?
    # Subscription callback block
    subscription_callback = lambda { |item,presence|
      case presence.type
        when :subscribe then       
          add_new_user(presence.from)
        when :unsubscribe then 
          remove_user(item)
      end
    }
    # Message callback block
    message_callback = lambda { |m|
      # Get data from message
      @log.debug "Responding to new message from #{m.from}"
      from_jid = Jabber::JID.new(m.from)
      message = m.body
      # Process
      unless m.type == :error or message.nil?
        @log.debug "... not an error"
        u = @roster.find(from_jid.strip)[from_jid.strip]
        dump_roster if @log.debug?
        if u.nil?
          @log.debug "... couldn't find user '#{from_jid.strip}' in roster - saying hello"
          send_message(from_jid, m.type, "Hi! I don't think I know you - please add me to your contact list, and I can update your #{@@service.name} status for you!")
        elsif m.body == 'exit' and from_jid.strip == @admin.jid
          @log.debug "... exit received"
          send_message(from_jid, m.type, "Exiting...")
          @mainthread.wakeup
        else
          @log.debug "... message is '#{message}'"
          key = from_jid.strip.to_s
          unless @sessions[key].nil?
            @log.debug "... storing session data in roster"
            response = @service.store_session(u, @sessions[key], message)
            @sessions[key] = nil
          else
            response = @service.set_status(u, message.unescapeHTML)
          end
          send_message(from_jid, m.type, response)
        end
      end
    }
    # Add callbacks
    @roster.add_subscription_callback(0, nil, &subscription_callback)
    @roster.add_subscription_request_callback(0, nil, &subscription_callback)
    @client.add_message_callback(0, nil, &message_callback)
  end

  def send_message(to, type, message)
    @log.debug "sending message to #{to} - '#{message}'"
    m = Jabber::Message::new(to, message)
    m.type = type
    @client.send(m)
  end
  
  def add_new_user(jid)
    @log.debug "adding new user #{jid.to_s}"
    # Accept subscription
    @roster.accept_subscription(jid)  
    key = jid.strip.to_s
    @sessions ||= {}
    @sessions[key] = @service.create_session
    response = @service.welcome_message(@sessions[key], jid)
    response.each { |msg| send_message jid, :chat, msg }
  end
  
  def remove_user(roster_item)
    @log.debug "removing #{roster_item.jid.to_s} from roster"
    roster_item.remove
    send_message roster_item.jid, :chat, "Goodbye #{roster_item.jid.node.capitalize}, thanks for using this service!"
  end

  def dump_roster
    @log.debug "Roster: #{@roster.items.size} items"
    @roster.items.each do |jid, item|
      @log.debug "- #{item.iname} (#{item.jid})"
    end
  end

  def close
    @client.close
  end
  
end