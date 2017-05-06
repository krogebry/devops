#!/usr/bin/env ruby
require './init.rb'
require 'sinatra'
require '../libs/cache.rb'
require '../libs/logger.rb'
require 'mongo'
require 'resque'

set :bind, '0.0.0.0'
set :port, ENV['PORT']

begin
  ## Database
  Mongo::Logger.logger.level = ::Logger::FATAL
  DB = Mongo::Client.new('mongodb://mongodb:27017', database: "cloudtrail")
  DB[:compressed_files].indexes.create_one({ filename: 1 }, { unique: true })
  DB[:records].indexes.create_one({ requestID: 1, eventID: 1 }, { unique: true })
  DB[:records].indexes.create_one({ eventTime: 1 })
  DB[:records].indexes.create_one({ eventName: 1 })
  DB[:records].indexes.create_one({ awsRegion: 1 })

rescue => e
  Log.fatal('Failed to connect to db!')
  exit

end

# begin
#   ## Cache
#   Cache = Dalli::Client.new(format('%s:11211', ENV['CACHE_HOSTNAME']))
#
# rescue => e
#   Log.fatal format('Unable to create cache connector: %s', e)
#   exit
#
# end

get '/' do
  tables = []

  begin
    # DB.tables.each do |table_name|
    #   tables.push({ :table => table_name, :cnt => DB[table_name].count })
    # end

  rescue => e
    Log.debug format('DB health problem! %s', e)

  end

  { 'success' => true, :tables => tables }.to_json
end

get '/healthz' do
  { 'success' => true }.to_json
end

# require './mounts/api/manager.rb'
# require './mounts/api/vendors.rb'
# require './mounts/api/producers.rb'
