##
# ECS things.
##

namespace :ecs do
  
  desc "Deploy"
  task :deploy, :version do |t,args|
    
    task_def = 'ECSCluster-0-1-4-taskdefinition-128BQ6327CY9:3'

    key = 'aws_task_def'
    json = Cache.cached_json( key ) do
      cmd_get_task = format('aws ecs describe-task-definition --task-definition %s', task_def)
      Log.debug(format('CMD(get_task): %s', cmd_get_task))
      `#{cmd_get_task}`
    end
    #pp json
    #exit

    container = json['taskDefinition']['containerDefinitions'].select{|cd| cd['name'] == 'wt-api' }.first
    #pp container
    #exit

    container['image'] = 'krogebry/wt-api:0.3.0'

    merged = json['taskDefinition']['containerDefinitions'].select{|cd| cd['name'] != 'wt-api' }.push( container )

    task_family = 'ECSCluster-0-1-4-taskdefinition-128BQ6327CY9'
    #service_name = 'ECSCluster-0-1-4-service-10IWXXFMF5GS5'
    service_name = 'ECSCluster-0-1-4-service-10IWXXFMF5GS5'

    skel = JSON::parse(File::read('/tmp/skel.json'))

    skel['family'] = task_family
    skel['networkMode'] = 'bridge'
    skel['volumes'] = json['taskDefinition']['volumes']
    skel['containerDefinitions'] = merged

    f = File.open('/tmp/update.json', 'w')
    f.write(skel.to_json)
    f.close

    cmd_update_task_def = format('aws ecs register-task-definition --cli-input-json file:///tmp/update.json')
    Log.debug(format('CMD(update_task_def): %s', cmd_update_task_def))
    system(cmd_update_task_def)

    task_def = 'ECSCluster-0-1-4-taskdefinition-128BQ6327CY9:5'

    cluster = 'ECSCluster-0-1-4-ECSCluster-TT1N9JUDLTDY'

    cmd_update_service = format('aws ecs update-service --cluster %s --service %s --task-definition %s', cluster, service_name, task_def)
    Log.debug(format('CMD(update_service): %s', cmd_update_service))
    system( cmd_update_service )
  end

end
