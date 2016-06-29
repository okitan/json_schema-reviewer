# coding: utf-8

Gem::Specification.new do |spec|
  spec.name          = "json_schema-review"
  spec.version       = File.read(File.expand_path("../VERSION", __FILE__)).chomp
  spec.authors       = ["okitan"]
  spec.email         = ["okitakunio@gmail.com"]

  spec.summary       = "Automatically Review JSON Schema"
  spec.description   = "Automatically Review JSON Schema"
  spec.homepage      = "https://github.com/okitan/json_schema-review"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "json_schema", ">= 0.12.5"

  spec.add_dependency "slop", "~> 4.0"

  # debug
  # spec.add_development_dependency "pry" # Gemfile

  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 10.0"
end
