require 'fileutils'

module Pod
  class Command
    class Nexus
      class Add < Nexus
        self.summary = 'Add a nexus repo.'

        self.description = <<-DESC
          添加一个nexus的repo
        DESC

        self.arguments = [
          CLAide::Argument.new('NAME', true),
          CLAide::Argument.new('URL', true)
        ]

        def initialize(argv)
          @name = argv.shift_argument
          @url = argv.shift_argument
          @silent = argv.flag?('silent', false)
          @silent = false
          super
        end

        def validate!
          super
          help! '需要配置`NAME`和`URL`.' unless @name && @url
        end

        def run
          UI.section("从#{@url}添加#{@name}仓库") do
            repos_path = File.join(@repos_nexus_dir, @name)
            raise Pod::Informative.exception "#{repos_path}已经存在. 请删除或者执行'pod nexus add #{@name} #{@url}'" if File.exist?(repos_path) && !@silent
            repo_dir_root = "#{@repos_nexus_dir}/#{@name}"

            FileUtils.mkdir_p repo_dir_root

            begin
              nexus_path = create_nexus_file(repo_dir_root)
            rescue StandardError => e
              raise Informative, "Cannot create file '#{nexus_path}' because : #{e.message}."
            end
            UI.puts "Successfully added repo #{@name}".green unless @silent
          end
        end

        def create_nexus_file(repo_dir_root)
          nexus_path = "#{repo_dir_root}/.nexus"
          nexus_path = File.new(nexus_path, 'wb')
          nexus_path << @url
          nexus_path.close
          nexus_path
        end
      end
    end
  end
end
