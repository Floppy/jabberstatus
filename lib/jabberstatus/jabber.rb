require 'openssl'
require 'digest/sha1'
require 'base64'

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
      def twitter_session=(credentials)
        # Create hashed password
        c = OpenSSL::Cipher::Cipher.new("aes-256-cbc")
        c.encrypt
        c.key = Digest::SHA1.hexdigest(TWITTER_CRYPT_KEY)
        c.iv = Digest::SHA1.hexdigest(TWITTER_CRYPT_IV)
        crypted_password = c.update(credentials[1])
        crypted_password << c.final
        # Encode
        crypted_password = Base64.encode64(crypted_password)
        @@log.debug "Storing twitter session for #{jid}"
        self.iname = "#{credentials[0]} #{crypted_password}"
        @@log.debug " - stored \"#{self.iname}\""
        send
      end
      def twitter_session
        @@log.debug "Restoring twitter session for #{jid}"
        username, crypted_password = self.iname.split
        # Decode
        crypted_password = Base64.decode64(crypted_password)
        # Decrypt password
        c = OpenSSL::Cipher::Cipher.new("aes-256-cbc")
        c.decrypt
        c.key = Digest::SHA1.hexdigest(TWITTER_CRYPT_KEY)
        c.iv = Digest::SHA1.hexdigest(TWITTER_CRYPT_IV)
        password = c.update(crypted_password)
        password << c.final
        return Twitter::Base.new(username, password)
      end
    end
  end
end