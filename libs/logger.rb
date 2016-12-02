##
# Logger extension thing.
##

module DevOps
  class Logger < Logger

    def formatter(severity, datetime, progname, msg)
      super(severity, datetime, progname, msg.dump)
    end

  end
end
