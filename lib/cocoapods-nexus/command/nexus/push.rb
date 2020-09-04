require 'cocoapods-nexus/api'

module Pod
  class Command
    class Nexus
      class Push < Nexus
        self.summary = 'Push a podspec.'

        self.description = <<-DESC
          Push a podspec to nexus.
        DESC

        self.arguments = [
          CLAide::Argument.new('NAME.podspec', true)
        ]

        def self.options
          [
            ['--url=url', 'a nexus hostname'],
            ['--repo=repo', 'a nexus repo'],
            ['--artifact=artifact', 'a nexus artifact']
          ].concat(super)
        end

        def initialize(argv)
          @podspec = argv.shift_argument
          @url = argv.option('url')
          @repo = argv.option('repo')
          @artifact = argv.option('artifact')
          super
        end

        def validate!
          super
          help! 'A podspec is required.' unless @podspec && File.exist?(File.expand_path(@podspec))
          help! 'A url is required.' unless @url
          help! 'A repo is required.' unless @repo
        end

        def run
          podspec_path = File.expand_path(@podspec)
          artifact_path = File.expand_path(@artifact) unless @artifact.nil?

          UI.section("开始发布 #{File.basename(@podspec)} -> #{@url}/nexus/#browse/browse:#{@repo}") do
            spec = Specification.from_file(podspec_path)
            artifact_id = spec.attributes_hash['name']
            version = spec.attributes_hash['version']
            group_id = 'Specs'

            if nexus_api.upload_maven_component(artifact_id: artifact_id,
                                                version: version,
                                                group_id: group_id,
                                                podspec: podspec_path,
                                                artifact: artifact_path,
                                                files: [])
              UI.puts "成功发布 #{artifact_id}(#{version})"
            else
              raise Informative, "发布失败 #{artifact_id}(#{version})，请检查~/.netrc文件或#{@repo}类型"
            end
          end
        end

        private

        def nexus_api
          @nexus_api ||= CocoapodsNexus::API.new(hostname: @url, repo: @repo)
        end
      end
    end
  end
end
