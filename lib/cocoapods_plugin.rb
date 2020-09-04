require 'cocoapods'
require 'cocoapods-nexus'

Pod::HooksManager.register('cocoapods-nexus', :source_provider) do |context, options|
  Pod::UI.message 'cocoapods-nexus received source_provider hook'
  unless (sources = options['sources'])
    raise Pod::Informative.exception 'cocoapods-nexus插件需要配置sources参数.'
  end

  sources.each do |source_config|
    name = source_config['name']
    url = source_config['url']
    source = Pod::NexusSource.new(File.join(Pod::Config.instance.repos_dir, name), url)
    update_or_add_source(source)
    context.add_source(source)
  end
end

def update_or_add_source(source)
  name = source.name
  url = source.url
  dir = source.repo

  unless dir.exist?
    argv = CLAide::ARGV.new([name, url])
    cmd = Pod::Command::Nexus::Add.new(argv)
    cmd.run
  end
end
