require 'cocoapods-nexus/api/connection'
require 'cocoapods-nexus/api/components'

module CocoapodsNexus
  # https://github.com/Cisco-AMP/nexus_api
  class API
    attr_accessor :connection
    attr_accessor :repo

    # 用于管理nexus服务器
    def initialize(hostname:, repo:)
      @connection = CocoapodsNexus::API::NexusConnection.new(hostname: hostname)
      @repo = repo
    end
  end
end