module CocoapodsNexus
  class API
    # 搜索组件
    def search_maven_component(artifact_id:)
      @connection.get_response(endpoint: "search?repository=#{@repo}&name=#{artifact_id}")
    end

    # 上传组件
    def upload_maven_component(artifact_id:, version:, group_id:, podspec:, artifact:, podspec_hook:, files:)
      parameters = {
        'maven2.artifactId' => artifact_id,
        'maven2.version' => version,
        'maven2.groupId' => group_id,
        'maven2.generate-pom' => true,
        'maven2.packaging' => artifact.nil? ? 'podspec' : File.extname(artifact).delete('.')
      }
      upload_files = []
      unless podspec.nil?
        upload_files << {
          'file' => podspec,
          'extension' => 'podspec',
          # 'classifier' => 'podspec'
        }
      end
      unless artifact.nil?
        upload_files << {
          'file' => artifact,
          'extension' => File.extname(artifact).delete('.')
        }
      end
      unless podspec_hook.nil?
        upload_files << {
          'file' => podspec_hook,
          'extension' => 'rb',
          'classifier' => 'podspec_hook'
        }
      end

      unless files.nil?
        upload_files |= files.map do |file|
          {
            'file' => file,
            'extension' => File.extname(file).delete('.'),
          }
        end
      end

      upload_files.each_index do |index|
        parameters["maven2.asset#{index + 1}"] = File.open(upload_files[index]['file'], 'r:utf-8')
        parameters["maven2.asset#{index + 1}.extension"] = upload_files[index]['extension'] unless upload_files[index]['extension'].nil?
        parameters["maven2.asset#{index + 1}.classifier"] = upload_files[index]['classifier'] unless upload_files[index]['classifier'].nil?
      end
      @connection.post(endpoint: "components?repository=#{@repo}", parameters: parameters, headers: {})
    end
  end
end
