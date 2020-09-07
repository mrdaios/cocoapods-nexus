# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name = 'cocoapods-nexus'
  spec.version = "0.0.5"
  spec.authors = ['mrdaios']
  spec.email = ['mrdaios@gmail.com']
  spec.description = 'a cocoapods plugin for nexus.'
  spec.summary = '运行时修改spec的source为nexus中的预编译的zip.'
  spec.homepage = 'https://github.com/mrdaios/cocoapods-nexus'
  spec.license = 'MIT'

  spec.files         = `git ls-files`.split($/)
  # spec.files = Dir['lib/**/*']
  spec.executables = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'cocoapods', '>= 1.9.3'
  spec.add_runtime_dependency 'rest-client', '~> 2.1.0'
  spec.add_runtime_dependency 'versionomy', '~> 0.5.0'

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake', '~> 13.0'
end
