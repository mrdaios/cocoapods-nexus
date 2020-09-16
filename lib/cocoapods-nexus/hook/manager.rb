require 'cocoapods'
require 'cocoapods-nexus/nexus_source'

module Pod
  class Source
    class Manager

      alias orgin_source_from_path source_from_path
      # 根据nexus配置文件加载source
      def source_from_path(path)
        @new_sources_by_path ||= Hash.new do |hash, key|
          nexus_file_path = File.join(key, ".nexus")
          hash[key] = if File.exist?(nexus_file_path)
                        Pod::NexusSource.new(key, File.read(nexus_file_path))
                      else
                        orgin_source_from_path(key)
                      end
        end
        @new_sources_by_path[path]
      end

      alias orgin_source_with_url source_with_url
      # 让nexus支持多repo
      def source_with_url(url)
        nil
      end
    end
  end
end
