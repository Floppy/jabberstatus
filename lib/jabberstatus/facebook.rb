require 'facebooker'
require 'jabberstatus/jabber'

class FacebookService

  def self.enabled?
    FB_API_KEY && FB_API_SECRET
  end
  
  def initialize(options = {})
    @log = options[:log]
  end
  
  def name
    "Facebook"
  end
  
  def create_session
    Facebooker::Session::Desktop.create( FB_API_KEY, FB_API_SECRET )
  end

  def welcome_message(session, jid)
    # Create welcome messages
    [ "Hi there #{jid.node.capitalize}! I can update your Facebook status for you if you like, but I need you to do a couple of things for me in order to do so.",
      "Please go to #{session.login_url} and log in. Make sure you check the box which says 'save my login info'.",
      "Then, please go to http://www.facebook.com/authorize.php?api_key=#{FB_API_KEY}&v=1.0&ext_perm=status_update, check the box and click OK.",
      "When you've done those, come back here and let me know (just type OK or something).",
      "By the way, if you want to know more about me, go to http://www.jabberstatus.org" ]
  end
 
  def store_session(user, session, message_data)
    @log.debug "... storing Facebook session data in roster"
    session.secure!
    user.facebook_session = session
    @log.debug "... done"
    "Thanks! You should now be able to set your status by just sending me a message. For instance, if you send 'is using JabberStatus', I will set your Facebook status to 'Yourname is using JabberStatus'. Try it out!"
  rescue
    "Sorry - something went wrong! We couldn't get the right details from Facebook. Did you check the 'save my login info' box?"
  end
  
  def set_status(user, message)
    @log.debug "setting Facebook status for #{user.jid.to_s} to \"#{message}\""
    session = user.facebook_session
    session.user.status = message
    "I set your Facebook status to: '#{session.user.name} #{session.user.status.message}'"
  rescue
    "Sorry - something went wrong!"
  end
  
end