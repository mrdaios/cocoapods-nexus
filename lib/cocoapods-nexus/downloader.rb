require 'cocoapods-downloader/remote_file'

module Pod
  module Downloader
    class NexusHttp < RemoteFile
      def self.options
        [:type, :name]
      end

      private

      executable :curl

      def download!
        @filename = "#{options[:name]}.#{'podspec'.to_sym}"
        @download_path = @target_path + @filename
        download_file(@download_path)
      end

      def download_file(full_filename)
        parameters = ['-f', '-L', '-o', full_filename, url, '--create-dirs', '--netrc-optional', '--retry', '2']
        parameters << user_agent_argument if headers.nil? ||
            headers.none? { |header| header.casecmp(USER_AGENT_HEADER).zero? }
        unless headers.nil?
          headers.each do |h|
            parameters << '-H'
            parameters << h
          end
        end
        # 通过curl下载文件
        curl! parameters
      end

      def user_agent_argument
        "-A cocoapods-nexus"
      end
    end
  end
end
