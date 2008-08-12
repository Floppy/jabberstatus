# Copyright (c) 2008 James Smith (www.floppy.org.uk)
#
# http://www.opensource.org/licenses/mit-license.php

class String
  def unescapeHTML
    string = CGI::unescapeHTML(self)
    # CGI::unescapeHTML doesn't replace &apos, but we need to.
    string.gsub("&apos;", "'")
  end
end