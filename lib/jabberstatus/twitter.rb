# Copyright (c) 2008 James Smith (www.floppy.org.uk)
#
# http://www.opensource.org/licenses/mit-license.php

require 'openssl'
require 'digest/sha1'
require 'base64'
require 'rubygems'
require 'twitter'

require 'jabberstatus/jabber'

class TwitterService

  def initialize(options = {})
    @log = options[:log]
    @crypt_key = options['twitter_crypt_key']
    @crypt_iv = options['twitter_crypt_iv']
    if @crypt_key.nil? || @crypt_iv.nil?
      @log.debug "Twitter service creation failed"
      raise "Twitter service creation failed - configuration info missing!"
    end
    @log.debug "Twitter service created"
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
    store_session_in_roster(user, twitter_credentials)
    @log.debug "... done"
    "Thanks! You should now be able to set your status by just sending me a message. You can also just send ? to get your current status. Try it out!"
  rescue
    "Sorry - something went wrong!"
  end

  def set_status(user, message)
    @log.debug "setting Twitter status for #{user.jid.to_s} to \"#{message}\""
    return "Sorry, Twitter only allows 140 characters, and you wrote #{message.length}." if message.length > 140
    twitter = retrieve_session_from_roster(user)
    twitter.post(message, :source => 'jabberstatus')
    "I set your status to '#{message}'"
  rescue
    "Sorry - something went wrong!"
  end

  def get_status(user)
    @log.debug "getting Twitter status for #{user.jid.to_s}"
    twitter = retrieve_session_from_roster(user)
    twitter.timeline(:user, :count => 1).first.text
  rescue
    "Sorry - something went wrong!"
  end

  protected

  def store_session_in_roster(user, credentials)
    # Create hashed password
    c = OpenSSL::Cipher::Cipher.new("aes-256-cbc")
    c.encrypt
    c.key = Digest::SHA1.hexdigest(@crypt_key)
    c.iv = Digest::SHA1.hexdigest(@crypt_iv)
    crypted_password = c.update(credentials[1])
    crypted_password << c.final
    # Encode
    crypted_password = Base64.encode64(crypted_password)
    @log.debug "Storing twitter session for #{user.jid}"
    user.session_data = [credentials[0], crypted_password]
    @log.debug " - stored \"#{user.iname}\""
  end
  
  def retrieve_session_from_roster(user)
    @log.debug "Restoring twitter session for #{user.jid}"
    username, crypted_password = user.session_data
    # Decode
    crypted_password = Base64.decode64(crypted_password)
    # Decrypt password
    c = OpenSSL::Cipher::Cipher.new("aes-256-cbc")
    c.decrypt
    c.key = Digest::SHA1.hexdigest(@crypt_key)
    c.iv = Digest::SHA1.hexdigest(@crypt_iv)
    password = c.update(crypted_password)
    password << c.final
    return Twitter::Base.new(username, password)
  end

end