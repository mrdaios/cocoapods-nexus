module CocoapodsNexus
  class API
    # 搜索组件
    def search_maven_component(artifact_id:)
      @connection.get_response(endpoint: "search?repository=#{@repo}&name=#{artifact_id}")
    end

    # 上传组件
    def upload_maven_component(artifact_id:, version:, group_id:, podspec:, artifact:, files:)
      parameters = {
        'maven2.artifactId' => artifact_id,
        'maven2.version' => version,
        'maven2.groupId' => group_id,
        'maven2.generate-pom' => true,
        'maven2.packaging' => artifact.nil? ? 'podspec' : File.extname(artifact).delete(".")
      }
      upload_files = []
      upload_files << podspec unless podspec.nil?
      upload_files << artifact unless artifact.nil?
      upload_files | files unless files.nil?

      upload_files.each_index do |index|
        parameters["maven2.asset#{index + 1}"] = File.open(upload_files[index], 'r:utf-8')
        parameters["maven2.asset#{index + 1}.extension"] = File.extname(upload_files[index]).delete(".")
      end
      @connection.post(endpoint: "components?repository=#{@repo}", parameters: parameters, headers: {})
    end
  end
end
