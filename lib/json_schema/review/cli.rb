require "json_schema/review"

module JsonSchema::Review
  class CLI
    def initialize(files, options)
      @files  = files
      @option = options
    end

    def run
    end
  end
end


if $0 == __FILE__
  ::JsonSchema::Review::CLI.start
end
