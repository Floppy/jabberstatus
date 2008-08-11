require 'jabberstatus/facebook'
require 'jabberstatus/twitter'

module ServiceFactory
  def self.create_service(options)
    if FacebookService.enabled?
      options[:log].debug "Creating Facebook service"
      return FacebookService.new(options)
    elsif TwitterService.enabled?
      options[:log].debug "Creating Twitter service"
      return TwitterService.new(options)
    end
  end
end