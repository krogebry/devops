##
# Main init thing.
##
require 'pp'
require 'json'
require 'logger'

begin
  Log = Logger.new(STDERR)

rescue => e
  Log.fatal("Failed to bootstrap") 
  exit

end
