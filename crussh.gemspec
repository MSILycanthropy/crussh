# frozen_string_literal: true

require_relative "lib/crussh/version"

Gem::Specification.new do |spec|
  spec.name = "crussh"
  spec.version = Crussh::VERSION
  spec.authors = ["MSILycanthropy"]
  spec.email = ["ethanmichaelk@gmail.com"]

  spec.summary = "TODO: Write a short summary, because RubyGems requires one."
  spec.description = "TODO: Write a longer description or delete this line."
  spec.homepage = "TODO: Put your gem's website or public repo URL here."
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "TODO: Put your gem's public repo URL here."
  spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(["git", "ls-files", "-z"], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?("bin/", "Gemfile", ".gitignore", "test/", ".github/", ".rubocop.yml")
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.extensions = ["ext/poly1305/extconf.rb"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency("activesupport", ">= 8.0")
  spec.add_dependency("async", "~> 2.35")
  spec.add_dependency("ed25519", "~> 1.4")
  spec.add_dependency("io-endpoint", "~> 0.16")
  spec.add_dependency("io-stream", "~> 0.11")
  spec.add_dependency("rb_sys", "~> 0.9.103")
  spec.add_dependency("ssh_data", "~> 2.0.0")
  spec.add_dependency("x25519", "~> 1.0.10")
  spec.add_dependency("zeitwerk", "~> 2.6e")

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
