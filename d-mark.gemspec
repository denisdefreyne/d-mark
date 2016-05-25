require_relative 'lib/d-mark/version'

Gem::Specification.new do |s|
  s.name        = 'd-mark'
  s.version     = DMark::VERSION
  s.homepage    = 'http://rubygems.org/gems/d-mark'
  s.summary     = 'markup language for writing text'
  s.description = 'D★Mark is a markup language aimed at being able to write semantically meaningful text without limiting itself to the semantics provided by HTML or Markdown.'

  s.author  = 'Denis Defreyne'
  s.email   = 'denis.defreyne@stoneship.org'
  s.license = 'MIT'

  s.files =
    Dir['[A-Z]*'] +
    Dir['{lib,spec,samples}/**/*'] +
    ['d-mark.gemspec']
  s.require_paths = ['lib']

  s.rdoc_options     = ['--main', 'README.adoc']
  s.extra_rdoc_files = ['LICENSE', 'README.adoc', 'NEWS.md']

  s.required_ruby_version = '>= 2.2.0'

  s.add_development_dependency('bundler', '>= 1.11.2', '< 2.0')
end
