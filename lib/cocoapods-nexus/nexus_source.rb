require 'cocoapods-nexus/api'
require 'cocoapods-nexus/downloader'
require 'versionomy'
require 'cocoapods-nexus/hook/specification'

module Pod
  class NexusSource < Source
    def initialize(repo, url)
      @source_url = url
      super(repo)
    end

    def url
      if @source_url
        @source_url.to_s
      else
        # after super(repo) repo is now the path to the repo
        File.read("#{repo}/.nexus") if File.exist?("#{repo}/.nexus")
      end
    end

    def git?
      false
    end

    def type
      'nexus'
    end

    # 从nexus查询依赖
    # @param [Object] query
    def search(query)
      unless File.exist?("#{repo}/.nexus")
        raise Informative, "Unable to find a source named: `#{name}`"
      end

      found = find_local_podspec(query)
      # 本地没查询到，则从nexus服务查询
      if found == []
        # 暂时这样处理
        spec_version = query.requirement.requirements.last.last.to_s
        artifacte = nexus_find_artifacte(spec_name: query.root_name, spec_version: spec_version)
        if artifacte
          download_url = parse_artifacte_asset_url(artifacte, 'podspec')
          if download_url
            target_path = "#{@repo}/#{query.root_name}/#{spec_version}"
            downloader = Pod::Downloader::NexusHttp.new(target_path, download_url, {:type => 'podspec', :name => query.root_name})
            downloader.download

            found = find_local_podspec(query)
          end
        end
      end

      if found == [query.root_name]
        set = set(query.root_name)
        set if set.specification_name == query.root_name
      end
    end

    def specification(name, version)
      specification = super
      version = version.version if version.is_a?(Pod::Version)
      artifacte = nexus_find_artifacte(spec_name: name, spec_version: version)
      download_url = parse_artifacte_asset_url(artifacte, 'zip')
      if download_url
        specification.attributes_hash['source'] = {
            'http' => download_url
        }

        # 执行自定义脚本
        podspec_rb_url = parse_artifacte_asset_url(artifacte, 'podspec_hook.rb')
        if podspec_rb_url
          tmpdir = Dir.tmpdir
          downloader = Pod::Downloader::NexusHttp.new(tmpdir, podspec_rb_url, {:type => 'rb', :name => name})
          downloader.download

          path = File.join(tmpdir, "#{name}.rb")
          if File.exist?(path)
            string = File.open(path, 'r:utf-8', &:read)
            if string
              Pod::Specification._eval_nexus_podspec(string, specification)
            end
          end
        else
          specification.attributes_hash['vendored_frameworks'] = "#{name}.framework"
        end
      end
      specification
    end

    private

    # 从本地repo查询spec
    def find_local_podspec(query)
      query = query.root_name if query.is_a?(Dependency)
      found = []
      Pathname.glob(pod_path(query)) do |path|
        next unless Dir.foreach(path).any? { |child| child != '.' && child != '..' }
        found << path.basename.to_s
      end
      found
    end

    # 解析附件downloadUrl
    def parse_artifacte_asset_url(artifacte, asset_type)
      asset = artifacte['assets'].select { |asset| asset['path'].end_with?(asset_type) }.first
      asset['downloadUrl'] if asset && asset['downloadUrl']
    end

    def nexus_find_artifacte(spec_name:, spec_version:)
      artifactes = nexus_api.search_maven_component(artifact_id: spec_name)
      # artifacte = artifactes.select { |artifacte| artifacte['version'].start_with?(spec_version) }.sort_by { |artifacte| Versionomy.parse(artifacte['version'])}.last
      # 暂时只支持查询指定版本
      artifacte = artifactes.select { |artifacte| artifacte['version'] == spec_version }.last
      artifacte
    end

    def nexus_api
      repo_name = File.basename(@repo).gsub('nexus_', '')
      @nexus_api ||= CocoapodsNexus::API.new(hostname: url, repo: repo_name)
    end
  end
end