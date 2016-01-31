require_relative 'lib/dmark/version'

Gem::Specification.new do |s|
  s.name        = 'dmark'
  s.version     = DMark::VERSION
  s.homepage    = 'http://rubygems.org/gems/dmark'
  s.summary     = 'markup language for writing text'
  s.description = 'D★Mark is a markup language aimed at being able to write semantically meaningful text without limiting itself to the semantics provided by HTML or Markdown.'

  s.author  = 'Denis Defreyne'
  s.email   = 'denis.defreyne@stoneship.org'
  s.license = 'MIT'

  s.files =
    Dir['[A-Z]*'] +
    Dir['{bin,lib,tasks,spec,samples,scripts}/**/*'] +
    ['dmark.gemspec']
  s.require_paths = ['lib']

  s.rdoc_options     = ['--main', 'README.md']
  s.extra_rdoc_files = ['LICENSE', 'README.md', 'NEWS.md']

  s.required_ruby_version = '>= 2.1.0'

  s.add_development_dependency('bundler', '>= 1.11.2', '< 2.0')
end
