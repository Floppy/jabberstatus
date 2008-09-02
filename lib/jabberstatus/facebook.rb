# Copyright (c) 2008 James Smith (www.floppy.org.uk)
#
# http://www.opensource.org/licenses/mit-license.php
 
require 'rubygems'
require 'facebooker'

require 'jabberstatus/jabber'

class FacebookService

  def initialize(options = {})
    @log = options[:log]
    @api_key = options['facebook_api_key']
    @api_secret = options['facebook_api_secret']
    if @api_key.nil? || @api_secret.nil?
      @log.debug "Facebook service creation failed"
      raise "Facebook service creation failed - configuration info missing!"
    end
    @log.debug "Facebook service created"
  end
  
  def name
    "Facebook"
  end
  
  def create_session
    Facebooker::Session::Desktop.create( @api_key, @api_secret )
  end

  def welcome_message(session, jid)
    # Create welcome messages
    [ "Hi there #{jid.node.capitalize}! I can update your Facebook status for you if you like, but I need you to do a couple of things for me in order to do so.",
      "Please go to #{session.login_url} and log in. Make sure you check the box which says 'save my login info'.",
      "Then, please go to http://www.facebook.com/authorize.php?api_key=#{@api_key}&v=1.0&ext_perm=status_update, check the box and click OK.",
      "When you've done those, come back here and let me know (just type OK or something).",
      "By the way, if you want to know more about me, go to http://www.jabberstatus.org" ]
  end
 
  def store_session(user, session, message_data)
    @log.debug "... storing Facebook session data in roster"
    session.secure!
    store_session_in_roster(user, session)
    @log.debug "... done"
    "Thanks! You should now be able to set your status by just sending me a message. For instance, if you send 'is using JabberStatus', I will set your Facebook status to 'Yourname is using JabberStatus'. Try it out!"
  rescue
    "Sorry - something went wrong! We couldn't get the right details from Facebook. Did you check the 'save my login info' box?"
  end
  
  def set_status(user, message)
    @log.debug "setting Facebook status for #{user.jid.to_s} to \"#{message}\""
    session = retrieve_session_from_roster(user)
    session.user.status = message
    "I set your Facebook status to: '#{session.user.name} #{session.user.status.message}'"
  rescue
    "Sorry - something went wrong!"
  end

  def get_status(user)
    @log.debug "getting Facebook status for #{user.jid.to_s} to \"#{message}\""
    session = retrieve_session_from_roster(user)
    "#{session.user.name} #{session.user.status.message}"
  rescue
    "Sorry - something went wrong!"
  end
  
protected

  def store_session_in_roster(user, session)
    if session.infinite?
      user.session_data = [session.session_key, session.user.id, session.auth_token, session.secret_for_method(nil)]
    else
      raise "Facebook session for #{user.jid.to_s} is not infinite!"
    end
  end
 
  def retrieve_session_from_roster(user)
    @log.debug "Restoring facebook session for #{user.jid.to_s}"
    session_key, session_uid, session_auth_token, secret_from_session = user.session_data
    session = Facebooker::Session::Desktop.create( @api_key, @api_secret )
    session.auth_token = session_auth_token
    session.secure_with!(session_key, session_uid, 0, secret_from_session)
    return session
  end
    
end
