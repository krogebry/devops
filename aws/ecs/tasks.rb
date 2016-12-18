##
# ECS things.
##

# TASK_DEF="ECSCluster-0-1-8-taskdefinition-101OE8BYVF9B0" 
# CLUSTER_NAME="ECSCluster-0-1-8-ECSCluster-F074YIKAK9P" 
# SERVICE_NAME="ECSCluster-0-1-8-service-1XYH19OERIEZN" 
# rake ecs:deploy['0.3.0']

def get_current_task_name( task_family_name )
  Log.debug(format('Looking for %s', task_family_name))

  cache_key = format('ecs_task_families_%s', task_family_name)

  tasks = Cache.cached_json( cache_key ) do
    ecs_client = Aws::ECS::Client.new(credentials: Aws::SharedCredentials.new())
    tasks = ecs_client.list_task_definitions({
      status: 'ACTIVE',
      family_prefix: task_family_name
    })
    tasks.data.to_h.to_json
  end
  #pp tasks

  tasks['task_definition_arns'].first
end

namespace :ecs do
  
  desc "Deploy"
  task :deploy, :version do |t,args|
    #task_family_name = 'ECSCluster-0-1-4-taskdefinition-128BQ6327CY9'
    #task_family_name = args[:task_family_name]
    cluster_name = ENV['CLUSTER_NAME']
    service_name = ENV['SERVICE_NAME']
    task_family_name = ENV['TASK_DEF']

    current_task_name = get_current_task_name( task_family_name )
    Log.debug(format('Current task name: %s', current_task_name))
    #exit

    cache_key = format('ecs_task_def_%s', current_task_name)
    json = Cache.cached_json( cache_key ) do
      cmd_get_task = format('aws ecs describe-task-definition --task-definition %s', current_task_name)
      Log.debug(format('CMD(get_task): %s', cmd_get_task))
      `#{cmd_get_task}`
    end
    #pp json
    #exit

    container = json['taskDefinition']['containerDefinitions'].select{|cd| cd['name'] == 'wt-api' }.first
    #pp container
    #exit

    container['image'] = format('krogebry/wt-api:%s', args[:version])

    merged = json['taskDefinition']['containerDefinitions'].select{|cd| cd['name'] != 'wt-api' }.push( container )

    #task_family = 'ECSCluster-0-1-4-taskdefinition-128BQ6327CY9'
    #service_name = 'ECSCluster-0-1-4-service-10IWXXFMF5GS5'
    #service_name = 'ECSCluster-0-1-4-service-10IWXXFMF5GS5'

    skel = JSON::parse(File::read('/tmp/skel.json'))

    skel['family'] = task_family_name
    skel['volumes'] = json['taskDefinition']['volumes']
    skel['networkMode'] = 'bridge'
    skel['containerDefinitions'] = merged

    f = File.open('/tmp/update.json', 'w')
    f.write(skel.to_json)
    f.close

    cmd_update_task_def = format('aws ecs register-task-definition --cli-input-json file:///tmp/update.json')
    Log.debug(format('CMD(update_task_def): %s', cmd_update_task_def))
    new_task = JSON::parse(`#{cmd_update_task_def}`)
    task_arn = new_task['taskDefinition']['taskDefinitionArn'].split(':')
    new_task_id = task_arn[task_arn.size-1]
    new_task_def_name = format('%s:%i', task_family_name, new_task_id)
    #new_task_def_name = task_arn.match(/\/(.*)$/)
    Log.debug(format('New task definition name: %s', new_task_def_name))
    #exit
    #pp new_task['taskDefinition'].keys
    #exit

    #task_def = 'ECSCluster-0-1-4-taskdefinition-128BQ6327CY9:5'
    #cluster = 'ECSCluster-0-1-4-ECSCluster-TT1N9JUDLTDY'

    #service_name = get_service_name( task_family_name )
    #cluster_name = get_cluster_name( task_family_name )

    cmd_update_service = format('aws ecs update-service --cluster %s --service %s --task-definition %s', cluster_name, service_name, new_task_def_name)
    Log.debug(format('CMD(update_service): %s', cmd_update_service))
    system( cmd_update_service )
  end

end
