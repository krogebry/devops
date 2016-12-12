##
# Utils
##

module DevOps
  class Utils

    ## TODO: do config stuff.
    def self.getDBConn
      Mongo::Client.new([ '127.0.0.1:27017' ], :database => format('aws-', ENV['AWS_PROFILE']))
    end

  end
end
