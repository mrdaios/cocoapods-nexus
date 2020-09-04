# require 'cocoapods-core'
# require 'cocoapods-nexus/api'

# module Pod
#     class Installer
#         alias_method :old_root_specs, :root_specs
#         def root_specs
#             # 通过修改specs的source到nexus下载zip（不完美的解决方案）
#             specs = old_root_specs
#             specs = specs.map{|spec| modify_spec_if_find_last_version(spec)}
#             specs
#         end

#         private

#         def modify_spec_if_find_last_version(spec)
#             attributes_hash = spec.attributes_hash
#             spec_name = attributes_hash['name']
#             spec_version = attributes_hash['version']
#             artifacte = nexus_find_artifacte(spec_name: spec_name, spec_version: spec_version)
#             if artifacte != nil
#                 asset_zip = artifacte['assets'].select{ |asset| asset['path'].end_with?('zip') }.first
#                 if asset_zip != nil 
#                     attributes_hash['source'] = {
#                         'http' => asset_zip['downloadUrl']
#                     }
#                     puts "Downloading #{spec_name}（#{spec_version}）from nexus(#{asset_zip['downloadUrl']})"
#                     spec.attributes_hash = attributes_hash
#                 end
#             end
#             spec
#         end

#         def nexus_find_artifacte(spec_name:, spec_version:)
#             artifacte = {}
#             api.each do |api|
#                 artifactes = api.search_maven_component(artifact_id: spec_name)
#                 artifacte = artifactes.select{ |artifacte| artifacte['version'].start_with?(spec_version) }.sort_by{ |artifacte| artifacte['version'].downcase }.last
#                 break if artifacte != nil
#             end
#             artifacte
#         end

#         def api
#             nexus_options = Pod::Config.instance.podfile.get_options || []
#             @apis = @apis || nexus_options.map{|nexus| CocoapodsNexus::API.new(hostname: nexus['endpoint'], repo: nexus['repo'])}
#         end
#     end
# end