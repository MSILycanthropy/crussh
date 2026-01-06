# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"
require "rubocop/rake_task"
require "rb_sys/extensiontask"

GEMSPEC = Gem::Specification.load("crussh.gemspec")

RbSys::ExtensionTask.new("poly1305", GEMSPEC) do |ext|
  ext.lib_dir = "lib/crussh/crypto"
  ext.cross_compile = true
  ext.cross_platform = [
    "x86_64-linux",
    "x86_64-linux-musl",
    "aarch64-linux",
    "x86_64-darwin",
    "arm64-darwin",
    "x64-mingw-ucrt",
  ]
end

Minitest::TestTask.create
RuboCop::RakeTask.new

task default: [:compile, :test, :rubocop]
task test: :compile
