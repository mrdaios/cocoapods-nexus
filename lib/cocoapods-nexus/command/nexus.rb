require 'cocoapods-nexus/nexus_source'

module Pod
  class Command
    class Nexus < Command
      require 'cocoapods-nexus/command/nexus/add'
      require 'cocoapods-nexus/command/nexus/list'
      require 'cocoapods-nexus/command/nexus/push'

      self.abstract_command = true

      self.summary = 'a cocoapods plugin for nexus'

      self.description = <<-DESC
        a cocoapods plugin for nexus.
      DESC

      def initialize(argv)
        @repos_nexus_dir = Pod::Config.instance.repos_dir
        super
      end
    end
  end
end
