require 'json'
require 'yaml'
require 'logger'

require './libs/cache.rb'
require './libs/logger.rb'

Log = DevOps::Logger.new(STDOUT)

namespace :docker do
  task :cleanup do
    commands = {}

    commands['kill_all'] = 'docker kill $(docker ps -q)'
    commands['delete_all_stopped'] = 'docker rm $(docker ps -a -q -f status=exited)'
    commands['delete_all_untagged'] = 'docker rmi $(docker images -q -f dangling=true)'
    commands['delete_all_images'] = 'docker rmi $(docker images -q)'
    commands['delete_none_images'] = 'docker rmi $(docker images|grep "none")'
    commands['clean_volumes'] = 'docker volume rm $(docker volume ls -qf dangling=true)'
    commands['hard_clean_volumes'] = 'docker volume rm -f $(docker volume ls|awk \'{print $2}\'|grep -v "VOLUME")'

    commands.each do |name, cmd|
      Log.debug('CMD[%s]: %s' % [name, cmd])
      system(cmd)
    end
  end
end

namespace :git do
  task :cleanup do
    commands = {}
    #commands['get merged'] = 'git branch --merged'
    commands['prune'] = 'git remote prune origin'
    commands['fetch'] = 'git fetch -p'

    commands.each do |name, cmd|
      Log.debug('CMD[%s]: %s' % [name, cmd])
      system(cmd)
    end
  end
end
