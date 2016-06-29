require "json_schema/review"

require "json"

module JsonSchema::Review
  class CLI
    attr_reader :files, :opts

    def initialize(files, opts)
      @files = files
      @opts  = opts
    end

    def run
      store = self.store

      files.each do |file|
        puts "Reviewing #{file}"
        if schema = load_schema(file)
          errors = resolve_reference!(schema, store: store)

          if !errors.empty? && opts[:check_resolve_reference]
            assign_error(file, "[ERROR] #{file} has unresolved reference", *errors)
          end

          # TODO: review against property
          unless opts[:no_check_schema_validation]
            Reviewer.new.review(schema).uniq.each do |review|
              if review.start_with?("[WARN]")
                # just show warning
                warn review
              else
                assign_error(file, review)
              end
            end
          end
        end
      end

      unless all_errors.empty?
        exit!
      end
    end

    def all_errors
      @all_errors ||= {}
    end

    def assign_error(file, *errors)
      warn errors.join("\n")

      all_errors[file] = errors
    end

    protected
    def load_schema(file)
      if ::File.exist?(file)
        begin
          return ::JsonSchema.parse!(::JSON.load(::File.read(file)))
        rescue ::JSON::ParserError => e
          assign_error(file, "[CRITICAL] #{file} is not valid json", e.message)
        rescue ::JsonSchema::AggregateError => e
          # e.to_s shows another exception orz
          assign_error(file, "[CRITICAL] #{file} is not valid json schema")
        rescue => e
          assign_error(file, "[CRITICAL] #{file} seems weired...", e.message)
        end
      else
        assign_error(file, "[CRITICAL] #{file} does not exist")
      end

      nil
    end

    def store
      if opts[:schema_dir]
        @store ||= begin
          puts "collecting store"
          store = ::JsonSchema::DocumentStore.new

          Dir[File.join(opts[:schema_dir], "**/*.json")].sort.each do |file|
            if schema = load_schema(file)
              begin
                store.add_schema(schema)
              rescue => e
                assign_error(file, "[CRITICAL] cannot add #{file} to store", e.message)
              end
            end
          end

          store.each {|key, value| value.expand_references(store: store) }

          store
        end
      end
    end

    def resolve_reference!(schema, store:)
      expander = ::JsonSchema::ReferenceExpander.new
      expander.expand(schema, store: store)

      expander.errors
    end
  end
end


if $0 == __FILE__
  ::JsonSchema::Review::CLI.start
end
