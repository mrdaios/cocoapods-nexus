require 'fileutils'
require 'cocoapods-nexus/nexus_source'

module Pod
  class Command
    class Nexus
      class List < Nexus
        self.summary = 'Add a nexus repo.'

        self.description = <<-DESC
          添加一个nexus的repo
        DESC

        def run
          repos_dir = Pod::Config.instance.repos_dir
          dirs = Dir.glob "#{repos_dir}/*/"
          repos = []
          dirs.each do |dir|
            next unless File.exist?("#{dir}/.nexus")
            url = File.read("#{dir}/.nexus")
            repos.push Pod::NexusSource.new(dir, url) if url
          end

          repos.each { |repo|
            UI.title repo.name do
              UI.puts "- URL: #{repo.url}"
              UI.puts "- Path: #{repo.repo}"
            end
          }
        end
      end
    end
  end
end
