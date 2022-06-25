# frozen_string_literal: true

require_relative "lib/rublox/treewalker/version"

Gem::Specification.new do |spec|
  spec.name = "rublox-treewalker"
  spec.version = Rublox::TreeWalker::VERSION
  spec.platform = "java"
  spec.authors = ["Zach Thomae"]
  spec.email = ["zach@thomae.co"]

  spec.summary = "A tree-walking interpreter for the Lox language"
  spec.homepage = "https://github.com/zthomae/rublox"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.5"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/zthomae/rublox"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "rublox-parser"
end
