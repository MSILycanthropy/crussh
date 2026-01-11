# frozen_string_literal: true

require_relative "lib/crussh/version"

Gem::Specification.new do |spec|
  spec.name = "crussh"
  spec.version = Crussh::VERSION
  spec.authors = ["MSILycanthropy"]
  spec.email = ["ethanmichaelk@gmail.com"]

  spec.summary = "A lowish-level SSH server library for Ruby"
  spec.homepage = "https://github.com/MSILycanthropy/crussh"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/MSILycanthropy/crussh"

  spec.files = Dir.glob([
    "LICENSE.txt",
    "README.md",
    "CHANGELOG.md",
    "lib/**/*",
    "ext/**/*",
    "sig/**/*",
  ]).reject { |f| File.directory?(f) }
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.extensions = ["ext/poly1305/extconf.rb"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency("activesupport", ">= 8.0")
  spec.add_dependency("async", ">= 2.0")
  spec.add_dependency("ed25519", ">= 1.0")
  spec.add_dependency("io-endpoint", ">= 0.1")
  spec.add_dependency("io-stream", ">= 0.1")
  spec.add_dependency("rb_sys", ">= 0.9")
  spec.add_dependency("ssh_data", ">= 2.0.0")
  spec.add_dependency("x25519", ">= 1.0.10")
  spec.add_dependency("zeitwerk", ">= 2")

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
