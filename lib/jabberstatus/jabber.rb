# Copyright (c) 2008 James Smith (www.floppy.org.uk)
#
# http://www.opensource.org/licenses/mit-license.php

module Jabber
  module Roster
    class RosterItem
      def session_data=(data)
        self.iname = data.join(' ')
        send
      end
      def session_data
        self.iname.split
      end
    end
  end
end