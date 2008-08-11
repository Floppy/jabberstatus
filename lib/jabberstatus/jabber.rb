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