## 
# Rakefile
##

# /usr/local/Cellar/node/6.1.0/libexec/npm/lib/node_modules/lambda-local/bin/lambda-local -l log-ids.js -h handler -e ../log.test.json 

def package_lambda( project_name )
  cmd_zip = format('cd lambda/%s; zip -q -r %s.zip %s.js ../node_modules/*', project_name, project_name, project_name)
  Log.debug(format('CMD(zip): %s', cmd_zip))
  system(cmd_zip)
end

def create_lambda_package(project_name, arn)
  cmd = format('aws lambda create-function --function-name %s --zip-file fileb://./lambda/%s/%s.zip --role %s --handler %s.handler --runtime nodejs',
                  project_name, 
                  project_name, 
                  project_name,
                  arn,
                  project_name)
  Log.debug(format('CMD(create): %s', cmd))
  system(cmd)
end

def update_lambda_package(project_name, arn, profile_name='default')
  cmd = format('aws --profile %s lambda update-function-code --function-name %s --zip-file fileb://./lambda/%s/%s.zip', profile_name, project_name, project_name, project_name)
  Log.debug(format('CMD(update): %s', cmd))
  system(cmd)
end

def package_created?(project_name, profile_name='default')
  cmd_list_functions = format('aws lambda list-functions')
  json = JSON::parse(`#{cmd_list_functions}`) 
  #pp json
  return json["Functions"].select{|f| f["FunctionName"] == project_name }.compact.size == 0
end

namespace :lambda do

  desc 'Upload project to lambda thingie'
  task :upload, :package_name do |t,args|
    account_id = ENV['AWS_ACCOUNT_ID']
    arn = format('arn:aws:iam::%s:role/lambda_exec_role' % account_id)
    profile_name = ENV['AWS_PROFILE_NAME']

    package_lambda(args[:package_name])

    if package_created?(args[:package_name], profile_name)
      create_lambda_package(args[:package_name], arn)
    else
      update_lambda_package(args[:package_name], arn)
    end
  end

  desc 'add permission'
  task :add_perm, :project_name do |t,args|
    account_id = ENV['AWS_ACCOUNT_ID']
    source_arn = format('arn:aws:logs:us-east-1:%i:log-group:/var/log/secure:*', account_id)

    project_name = args[:project_name]

    cmd = format('aws lambda add-permission --function-name "%s" --statement-id "%s" ' \
      '--principal "logs.us-east-1.amazonaws.com" --action "lambda:InvokeFunction" ' \
      '--source-arn "%s" --source-account "%i"',
        project_name,
        project_name,
        source_arn,
        account_id)
    
    Log.debug(format('CMD(perm): %s', cmd))
    system(cmd)
  end

end
