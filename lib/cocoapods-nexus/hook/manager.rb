require 'cocoapods'
require 'cocoapods-nexus/nexus_source'

module Pod
  class Source
    class Manager
      alias orgin_source_from_path source_from_path

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
    end
  end
end
