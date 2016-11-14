##
# KMS stuff
##

namespace :kms do

  ##
  #
  ##
  desc "Encrypt some stuff."
  task :encrypt, :name, :target do |t,args|
    creds = Aws::SharedCredentials.new()

    s3_client = Aws::S3::Client.new(credentials: creds, signature_version: 'v4')
    kms_client = Aws::KMS::Client.new()

    ENV['KMS_KEY_ALIAS'] ||= 'alias/devops'

    aliases = kms_client.list_aliases.aliases

    key = aliases.find { |alias_struct| alias_struct.alias_name == ENV['KMS_KEY_ALIAS'] }
    key_id = key.target_key_id
    s3_encryption_client = Aws::S3::Encryption::Client.new(
      client: s3_client,
      kms_key_id: key_id,
      kms_client: kms_client,
    )

    target = 'rancher-mgt'
    env_name = 'management'
    source_file = File.join(File::SEPARATOR, 'tmp', env_name, format('%s.json' % target))
    begin
      s3_encryption_client.put_object(
        key: format('%s/%s', env_name, target),
        body: File.open(source_file),
        bucket: format('dev-central-%s', ENV['INF_VERSION'])
      )
    rescue => e
      Log.fatal(format('Failed: %s', e))
      pp e.backtrace
    end

  end

  ##
  # 
  ##
  desc "Decrypt some stuff."
  task :decrypt do |t,args|
    creds = Aws::SharedCredentials.new()
    s3_client = Aws::S3::Client.new(credentials: creds, signature_version: 'v4')

    kms_client = Aws::KMS::Client.new()

    ENV['KMS_KEY_ALIAS'] ||= 'alias/devops'

    aliases = kms_client.list_aliases.aliases
    key = aliases.find { |alias_struct| alias_struct.alias_name == ENV['KMS_KEY_ALIAS'] }
    key_id = key.target_key_id

    s3_encryption_client = Aws::S3::Encryption::Client.new(
      client: s3_client,
      kms_key_id: key_id,
      kms_client: kms_client,
    )

    target = 'rancher-mgt'
    env_name = 'management'
    source_file = File.join(File::SEPARATOR, 'tmp', env_name, format('%s.json' % target))

    begin
      response = s3_encryption_client.get_object(bucket: format('dev-central-%s', ENV['INF_VERSION']), key: format('%s/%s', env_name, target))
      # build string of env vars to be exported.
      File.open(source_file, 'w') do |f|
        f.write(response.body.read)
      end

    rescue => e
      Log.fatal(format('Failed: %s', e))
      pp e.backtrace
    end

  end

end
