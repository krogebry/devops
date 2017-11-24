## 
# Rakefile
##

# /usr/local/Cellar/node/6.1.0/libexec/npm/lib/node_modules/lambda-local/bin/lambda-local -l log-ids.js -h handler -e ../log.test.json 

def package_lambda( project_name )
  cmd_zip = format('cd lambda/%s; zip -q -r %s.zip index.js ../node_modules/*', project_name, project_name, project_name)
  LOG.debug(format('CMD(zip): %s', cmd_zip))
  system(cmd_zip)
  return format(File.join('lambda', project_name, format('%s.zip', project_name)))
end

def create_lambda_package(project_name, arn)
  cmd = format('aws lambda create-function --function-name %s --zip-file fileb://./lambda/%s/%s.zip --role %s --handler %s.handler --runtime nodejs',
                  project_name, 
                  project_name, 
                  project_name,
                  arn,
                  project_name)
  LOG.debug(format('CMD(create): %s', cmd))
  system(cmd)
end

def update_lambda_package(project_name)
  cmd = format('aws lambda update-function-code --function-name %s --zip-file fileb://./lambda/%s/%s.zip', project_name, project_name, project_name)
  LOG.debug(format('CMD(update): %s', cmd))
  system(cmd)
end

def package_created?(project_name, profile_name='default')
  cmd_list_functions = format('aws lambda list-functions')
  json = JSON::parse(`#{cmd_list_functions}`) 
  #pp json
  return json["Functions"].select{|f| f["FunctionName"] == project_name }.compact.size == 0
end

namespace :lambda do

  desc 'Upload lambda package to s3'
  task :upload, :package_name do |t,args|
    account_id = ENV['AWS_ACCOUNT_ID']
    #arn = format('arn:aws:iam::%s:role/lambda_exec_role' % account_id)
    profile_name = ENV['AWS_PROFILE_NAME']

    #s3_bucket = format('nm-lambda-functions-2016-12-02')
    s3_bucket = format('krogebry')

    creds = Aws::SharedCredentials.new()
    s3_client = Aws::S3::Client.new(credentials: creds)

    zip_file = package_lambda(args[:package_name])

    File.open( zip_file ) do |f|
      s3_client.put_object( bucket: s3_bucket, key: File::basename(zip_file) , body: f)
    end

    LOG.debug(format('File uploaded'))
  end

  desc 'Update project to lambda thingie'
  task :update, :package_name do |t,args|
    account_id = ENV['AWS_ACCOUNT_ID']
    arn = format('arn:aws:iam::%s:role/lambda_exec_role' % account_id)
    profile_name = ENV['AWS_PROFILE_NAME']

    package_lambda(args[:package_name])

    #if package_created?(args[:package_name], profile_name)
      #create_lambda_package(args[:package_name], arn)
    #else
      update_lambda_package(args[:package_name])
    #end
  end

  desc 'add role'
  task :add_role, :project_name do |t,args|
    creds = Aws::SharedCredentials.new()
    #ec2_client = Aws::EC2::Client.new(region: yaml['region'], credentials: creds)
    iam_client = Aws::IAM::Client.new(credentials: creds)

    #assume_role_policy_document = '{"Version":"2008-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":["ec2.amazonaws.com"]},"Action":["sts:AssumeRole"]}]}'
    policy_document = {
      "Version" => "2008-10-17",
      "Statement" => [{
        "Effect" => "Allow",
        "Action" => "lambda:*",
        "Principal" => "*"
      }]
    }

    role_arn = format('arn:aws:iam::123:role/%s', args[:project_name])

    policy = Aws::IAM::Policy.new( role_arn )
    policy.allow(:actions => ["s3:Get*","s3:List*"], :resources => '*')

    #resp = iam_client.create_policy({
      #policy_name: "lambda_exec", 
      #policy_document: policy_document
    #})

    iam_client.create_role(
      name: format('lambda_%s', args[:project_name]),
      assume_role_policy_document: policy_document.to_s
    )

    iam.client.put_role_policy(
      :role_name => role_name,
      :policy_name => policy_name,
      :policy_document => policy.to_json
    )

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
    
    LOG.debug(format('CMD(perm): %s', cmd))
    system(cmd)
  end

end
