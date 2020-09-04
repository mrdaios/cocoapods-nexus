# require 'cocoapods'
# require 'cocoapods-nexus/nexus_source'
#
# module Pod
#   class Installer
#     class Analyzer
#       alias orig_sources sources
#
#       # 修改pod的sources，用于注入cocoapods-nexus
#       def sources
#         value = orig_sources
#         if podfile.sources.empty? && podfile.plugins.key?('cocoapods-nexus')
#           sources = []
#           plugin_config = podfile.plugins['cocoapods-nexus']
#           # all sources declared in the plugin clause
#           plugin_config['sources'].uniq.map do |config|
#             name = config['name']
#             url = config['url']
#
#             sources.push(Pod::NexusSource.new("nexus_#{name}", url))
#           end
#           @sources = sources
#         else
#           orig_sources
#         end
#       end
#     end
#   end
# end
