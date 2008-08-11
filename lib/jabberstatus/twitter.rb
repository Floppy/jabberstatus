require 'twitter'
require 'jabberstatus/jabber'

class TwitterService

  def self.enabled?
    TWITTER_CRYPT_KEY && TWITTER_CRYPT_IV
  end

  def initialize(options = {})
    @log = options[:log]
  end
  
  def name
    "Twitter"
  end
  
  def create_session
    "pending"
  end
  
  def welcome_message(session, jid)
    # Create welcome messages
    [ "Hi there #{jid.node.capitalize}! I can update your Twitter status for you if you like, but I need your Twitter details in order to do so.",
      "Please send me your Twitter username and password, with a space in between. For instance, type 'james my_password'.",
      "By the way, if you want to know more about me, go to http://www.jabberstatus.org" ]
  end

  def store_session(user, session, message_data)
    twitter_credentials = message_data.squeeze(' ').split(' ')
    @log.debug "... extracting username #{twitter_credentials[0]} and password #{twitter_credentials[1]}"
    raise "bad credentials" if twitter_credentials.size != 2
    user.twitter_session = twitter_credentials
    @log.debug "... done"
    "Thanks! You should now be able to set your status by just sending me a message. Try it out!"
  rescue
    "Sorry - something went wrong!"
  end

  def set_status(user, message)
    @log.debug "setting Twitter status for #{user.jid.to_s} to \"#{message}\""
    twitter = user.twitter_session
    twitter.post(message)
    "I set your status to '#{message}'"
  rescue
    "Sorry - something went wrong!"
  end
  
end