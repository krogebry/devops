
class CloudTrailRedis
  def initialize(hostname)
    Resque.redis = '%s:6379' % hostname
  end
end

