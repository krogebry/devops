##
# Cache handler
##

module DevOps
  class Cache
    CACHE_TYPE_FILE = :file
    FS_CACHE_DIR = File.join('/', 'tmp', 'devops', 'cache')

    def initialize(cache_type=CACHE_TYPE_FILE)
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
      FileUtils.mkdir_p(File.dirname(fs_cache_file)) unless File.exists?(File.dirname(fs_cache_file))
      if File.exists?(fs_cache_file)
        data = File.read(fs_cache_file)
      else
        Log.debug('Getting from source')
        data = yield
        File.open(fs_cache_file, 'w') do |f|
          f.puts data
        end
      end
      JSON.parse(data)
    end

  end
end
