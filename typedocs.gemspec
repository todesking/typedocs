# -*- encoding: utf-8 -*-
require File.expand_path('../lib/typedocs/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["todesking"]
  gem.email         = ["discommunicative@gmail.com"]
  gem.summary       = %q{Human readable type annotations}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "typedocs"
  gem.require_paths = ["lib"]
  gem.version       = Typedocs::VERSION

  %w(rspec simplecov simplecov-vim).each do|dep|
    gem.add_development_dependency dep
  end
end
