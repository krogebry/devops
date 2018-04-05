module DevOps
  class Cache
    FS_CACHE_DIR = File.join('/', 'tmp', 'devops', 'cache')
    CACHE_TYPE_FILE = :file

    def initialize
      init_cache
    end

    def init_cache
      FileUtils.mkdir_p FS_CACHE_DIR
    end

    def del_key(key)
      system(format('rm -rf %s', File.join(FS_CACHE_DIR, key)))
    end

    def self.flush
      system(format('rm -rf %s/*', FS_CACHE_DIR))
    end

    def cached_json(key)
      fs_cache_file = File.join(FS_CACHE_DIR, key)
      FileUtils.mkdir_p(File.dirname(fs_cache_file)) unless File.exist?(File.dirname(fs_cache_file))
      if File.exist?(fs_cache_file)
        data = File.read(fs_cache_file)
      else
        LOG.debug('Getting from source')
        data = yield
        File.open(fs_cache_file, 'w') do |f|
          f.puts data
        end
      end
      JSON.parse(data)
    end

  end
end
