require 'concurrent'
require 'typhoeus'
require 'cocoapods-nexus/api'
require 'cocoapods-nexus/downloader'
require 'cocoapods-nexus/hook/specification'

module Pod
  class NexusSource < Source
    include Concurrent
    HYDRA_EXECUTOR = Concurrent::SingleThreadExecutor.new

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

    # @return [Array<Version>] all the available versions for the Pod, sorted
    #         from highest to lowest.
    #
    # @param  [String] name
    #         the name of the Pod.
    #
    def versions(name)
      return nil unless specs_dir
      raise ArgumentError, 'No name' unless name

      return @versions_by_name[name] unless @versions_by_name[name].nil?

      pod_path_actual = pod_path(name)
      pod_path_relative = pod_path(name).relative_path_from(repo)

      concurrent_requests_catching_errors do
        loaders = []
        components = nexus_api.search_maven_component(artifact_id: name)
        if !components.nil? && components.count > 0
          # 从服务器获取version
          @versions_by_name[name] ||= components.map do |component|
            # Optimization: ensure all the podspec files at least exist. The correct one will get refreshed
            # in #specification_path regardless.
            podspec_version_path_relative = Pathname.new(component["version"]).join("#{name}.podspec")

            unless pod_path_actual.join(podspec_version_path_relative).exist?
              remote_url = parse_artifacte_asset_url(component, 'podspec')
              # Queue all podspec download tasks first
              loaders << download_file_async(pod_path_relative.join(podspec_version_path_relative).to_s, remote_url)
            end

            begin
              Version.new(component["version"]) if component["version"][0, 1] != '.'
            rescue ArgumentError
              raise Informative, 'An unexpected version directory ' \
            "`#{component["version"]}` was encountered for the " \
            "`#{pod_path_actual}` Pod in the `#{name}` repository."
            end
          end.compact.sort.reverse
        end
        # Block and wait for all to complete running on Hydra
        Promises.zip_futures_on(HYDRA_EXECUTOR, *loaders).wait!
      end
      @versions_by_name[name]
    end

    # 从nexus查询依赖
    # @param [Object] query
    def search(query)
      unless File.exist?("#{repo}/.nexus")
        raise Informative, "Unable to find a source named: `#{name}`"
      end
      if query.is_a?(Dependency)
        query = query.root_name
      end

      # found = find_local_podspec(query)
      # # 本地没查询到，则从nexus服务查询
      # if found == []
      #   # 暂时这样处理
      #   spec_version = query.requirement.requirements.last.last.to_s
      #   artifacte = nexus_find_artifacte(spec_name: query.root_name, spec_version: spec_version)
      #   if artifacte
      #     download_url = parse_artifacte_asset_url(artifacte, 'podspec')
      #     if download_url
      #       target_path = "#{@repo}/#{query.root_name}/#{spec_version}"
      #       downloader = Pod::Downloader::NexusHttp.new(target_path, download_url, {:type => 'podspec', :name => query.root_name})
      #       downloader.download
      #
      #       found = find_local_podspec(query)
      #     end
      #   end
      # end

      # version信息暂时不缓存到本地
      components = nexus_api.search_maven_component(artifact_id: query)
      found = !components.nil? && components.count > 0 ? query : nil

      if found
        set = set(query)
        set if set.specification_name == query
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

    def concurrent_requests_catching_errors
      yield
    rescue MultipleErrors => e
      # aggregated error message from `Concurrent`
      errors = e.errors
      raise Informative, "CDN: #{name} Repo update failed - #{e.errors.size} error(s):\n#{errors.join("\n")}"
    end

    def download_file_async(partial_url, remote_url)
      file_remote_url = URI.encode(remote_url)
      path = repo + partial_url

      # file_okay = local_file_okay?(partial_url)
      # if file_okay
      #   if @startup_time < File.mtime(path)
      #     debug "CDN: #{name} Relative path: #{partial_url} modified during this run! Returning local"
      #     return Promises.fulfilled_future(partial_url, HYDRA_EXECUTOR)
      #   end
      #
      #   unless @check_existing_files_for_update
      #     debug "CDN: #{name} Relative path: #{partial_url} exists! Returning local because checking is only perfomed in repo update"
      #     return Promises.fulfilled_future(partial_url, HYDRA_EXECUTOR)
      #   end
      # end

      path.dirname.mkpath

      # etag_path = path.sub_ext(path.extname + '.etag')

      # etag = File.read(etag_path) if file_okay && File.exist?(etag_path)
      # debug "CDN: #{name} Relative path: #{partial_url}, has ETag? #{etag}" unless etag.nil?

      download_and_save_with_retries_async(partial_url, file_remote_url)
    end

    def download_and_save_with_retries_async(partial_url, file_remote_url, retries = 5)
      path = repo + partial_url
      # etag_path = path.sub_ext(path.extname + '.etag')

      download_task = download_typhoeus_impl_async(file_remote_url, nil).then do |response|
        case response.response_code
        when 301
          redirect_location = response.headers['location']
          # debug "CDN: #{name} Redirecting from #{file_remote_url} to #{redirect_location}"
          download_and_save_with_retries_async(partial_url, redirect_location, nil )
        when 304
          # debug "CDN: #{name} Relative path not modified: #{partial_url}"
          # We need to update the file modification date, as it is later used for freshness
          # optimization. See #initialize for more information.
          FileUtils.touch path
          partial_url
        when 200
          File.open(path, 'w') { |f| f.write(response.response_body.force_encoding('UTF-8')) }

          # etag_new = response.headers['etag'] unless response.headers.nil?
          # debug "CDN: #{name} Relative path downloaded: #{partial_url}, save ETag: #{etag_new}"
          # File.open(etag_path, 'w') { |f| f.write(etag_new) } unless etag_new.nil?
          partial_url
        when 404
          # debug "CDN: #{name} Relative path couldn't be downloaded: #{partial_url} Response: #{response.response_code}"
          nil
        when 502, 503, 504
          # Retryable HTTP errors, usually related to server overloading
          if retries <= 1
            # raise Informative, "CDN: #{name} URL couldn't be downloaded: #{file_remote_url} Response: #{response.response_code} #{response.response_body}"
          else
            # debug "CDN: #{name} URL couldn't be downloaded: #{file_remote_url} Response: #{response.response_code} #{response.response_body}, retries: #{retries - 1}"
            exponential_backoff_async(retries).then do
              download_and_save_with_retries_async(partial_url, file_remote_url, nil , retries - 1)
            end
          end
        when 0
          # Non-HTTP errors, usually network layer
          if retries <= 1
            raise Informative, "CDN: #{name} URL couldn't be downloaded: #{file_remote_url} Response: #{response.return_message}"
          else
            debug "CDN: #{name} URL couldn't be downloaded: #{file_remote_url} Response: #{response.return_message}, retries: #{retries - 1}"
            exponential_backoff_async(retries).then do
              download_and_save_with_retries_async(partial_url, file_remote_url, etag, retries - 1)
            end
          end
        else
          raise Informative, "CDN: #{name} URL couldn't be downloaded: #{file_remote_url} Response: #{response.response_code} #{response.response_body}"
        end
      end

      # Calling `Future#run` flattens the chained futures created by retries or redirects
      #
      # Does not, in fact, run the task - that is already happening in Hydra at this point
      download_task.run
    end

    def exponential_backoff_async(retries)
      sleep_async(backoff_time(retries))
    end

    def backoff_time(retries)
      current_retry = MAX_NUMBER_OF_RETRIES - retries
      4 * 2**current_retry
    end

    def sleep_async(seconds)
      # Async sleep to avoid blocking either the main or the Hydra thread
      Promises.schedule_on(HYDRA_EXECUTOR, seconds)
    end

    def download_typhoeus_impl_async(file_remote_url, etag)
      # Create a prefereably HTTP/2 request - the protocol is ultimately responsible for picking
      # the maximum supported protocol
      # When debugging with proxy, use the following extra options:
      # :proxy => 'http://localhost:8888',
      # :ssl_verifypeer => false,
      # :ssl_verifyhost => 0,
      request = Typhoeus::Request.new(
          file_remote_url,
          :method => :get,
          :http_version => :httpv2_0,
          :timeout => 10,
          :connecttimeout => 10,
          :accept_encoding => 'gzip',
          :netrc => :optional,
          :netrc_file => Netrc.default_path,
          :headers => etag.nil? ? {} : { 'If-None-Match' => etag },
          )

      future = Promises.resolvable_future_on(Concurrent::SingleThreadExecutor.new)
      queue_request(request)
      request.on_complete do |response|
        future.fulfill(response)
      end

      # This `Future` should never reject, network errors are exposed on `Typhoeus::Response`
      future
    end

    def queue_request(request)
      @hydra ||= Typhoeus::Hydra.new

      # Queue the request into the Hydra (libcurl reactor).
      @hydra.queue(request)

      # Cycle the reactor on a separate thread
      #
      # The way it works is that if more requests are queued while Hydra is in the `#run`
      # method, it will keep executing them
      #
      # The upcoming calls to `#run` will simply run empty.
      HYDRA_EXECUTOR.post(@hydra, &:run)
    end

  end
end