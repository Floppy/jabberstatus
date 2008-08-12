# Copyright (c) 2008 James Smith (www.floppy.org.uk)
#
# http://www.opensource.org/licenses/mit-license.php

require 'jabberstatus/facebook'
require 'jabberstatus/twitter'

module ServiceFactory
  def self.create_service(options)
    # Try to create services in turn - they will fail if required settings are not found
    return FacebookService.new(options) rescue nil
    return TwitterService.new(options) rescue nil
    raise "Couldn't create any services. Check config.yml"
  end
end