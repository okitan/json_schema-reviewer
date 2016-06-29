require "json_schema/review"

module JsonSchema::Review
  class Reviewer
    def review(schema)
      errors = []
      #errors.push(*review_schema(schema))
      errors.push(*review_links(schema.links))
    end

    def review_schema(schema)
      errors = []

      errors.push(*review_type(schema))

      errors
    end

    # basically
    def review_type(schema)
      return [] if schema.enum

      try_compact = compact_schema(schema)

      if try_compact
        return review_type(try_compact)
      end

      errors = []

      position = schema.id.to_s + schema.pointer
      type = schema.type

      level = type.empty? ? "[WARN]" : "[ERROR]"

      # validation keywords for number and integer
      unless type.include?("number") || type.include?("integer")
        %w[ multiple_of min min_exclusive max max_exclusive ].each do |key|
           if schema.__send__(key)
             key = convert_key(key).sub("min", "minimum").sub("max", "maximum")
             errors.push("#{level} #{position}/#{key} is defined but type does not include number or integer")
          end
        end
      else
        %w[ min max ].each do |key|
          unless schema.__send__(key)
            key = convert_key(key).sub("min", "minimum").sub("max", "maximum")
            errors.push("[ERROR] #{position}/#{key} is not defined for type number or integer")
          end
        end
      end

      # validation keywords for string
      unless type.include?("string")
        %w[ min_length max_length pattern ].each do |key|
          if schema.__send__(key)
            errors.push("#{level} #{position}/#{convert_key(key)} is defined but type does not include string")
          end
        end
      else
        unless schema.format
          if schema.pattern
            # TODO: parse pattern and check it
          else
            unless schema.max_length
              errors.push("[ERROR] #{position}/maxLength is not defined for type string which has no format nor pattern")
            end
          end
        end
      end

      # validation keywords for array
      unless type.include?("array")
        %w[ min_items max_items items ].each do |key|
          if schema.__send__(key)
            errors.push("#{level} #{position}/#{convert_key(key)} is defined but type does not include array")
          end
        end
        unless schema.additional_items === true
          errors.push("#{level} #{position}/additionalItems is defined but type does not include array")
        end
      else
        unless schema.max_items || schema.additional_items === false
          errors.push("[ERROR] #{position} allows unlimited items")
        end
      end

      # validation keywords for object
      unless type.include?("object")
        %w[ min_properties max_properties required ].each do |key|
          if schema.__send__(key)
            errors.push("#{level} #{position}/#{convert_key(key)} is defined but type does not include object")
          end
        end
        unless schema.additional_properties === true
          errors.push("#{level} #{position}/additionalProperties is defined but type does not include object")
        end
        %w[ properties pattern_properties ].each do |key|
          unless schema.__send__(key).empty?
            errors.push("#{level} #{position}/#{convert_key(key)} is defined but type does not include object")
          end
        end
      else # TODO: or type.empty?
        unless schema.max_properties || schema.additional_properties === false
          # pattern properties can limit any properties
          this_level = schema.pattern_properties.empty? ? "[ERROR]" : "[WARN]"
          errors.push("#{this_level} #{position} allows any additional properties")
        end
      end

      # children
      # object
      begin
        %w[ properties pattern_properties ].each do |key|
          schema.__send__(key).each do |k, v|
            errors.push(*review_type(v))
          end
        end
        # schema array or schema
        %w[ one_of all_of any_of items additional_properties ].each do |key|
          items = schema.__send__(key)

          if items.is_a?(Array)
            items.each {|item| errors.push(*review_type(item)) }
          elsif items.is_a?(::JsonSchema::Schema)
            errors.push(*review_type(items))
          end
        end
      rescue => e
        raise e
      end

      errors
    end

    def review_links(links)
      errors = []

      links.each do |link|
        next unless link.schema

        errors.push(*review_schema(link.schema))
      end

      errors
    end

    protected
    def convert_key(key)
      key.gsub(/_(\w)/) { $1.upcase }
    end

    # really heuristics
    def compact_schema(schema)
      #warn "[INFO] start to merge #{schema.id.to_s + schema.pointer}"

      # unable to merge complex schema
      unless (schema.one_of.size + schema.any_of.size + schema.all_of.size) == 1
        return nil
      end
      to_merge = schema.one_of.first || schema.any_of.first || schema.all_of.first

      unless to_merge.expanded?
        return nil
      end
      #return nil unless to_merge.expanded?

      #warn "[INFO] merging #{schema.id.to_s + schema.pointer}"

      new_schema = ::JsonSchema::Schema.new
      new_schema.copy_from(schema)
      new_schema.fragment = schema.fragment

      # remove
      new_schema.one_of, new_schema.all_of, new_schema.any_of = [], [], []

      %w[ multiple_of max max_exclusive min min_exclusive
          max_length min_length pattern
          items max_items min_items max_items unique_items
          max_properties min_properties required dependencies
          enum not
      ].each do |key|
        if override = to_merge.__send__(key)
          original = new_schema.__send__(key)

          if original
            unless original == override
              warn "[MERGE] #{schema.id.to_s + schema.pointer}/#{key}: #{original} #{override}"
            end
          else
            new_schema.__send__("#{key}=", override)
          end
        end
      end

      # default is true
      %w[ additional_items additional_properties ].each do |key|
        original = new_schema.__send__(key)
        override = to_merge.__send__(key)

        if original === true
          new_schema.__send__("#{key}=", override)
        else
          unless override === true
            warn "[MERGE] #{schema.id.to_s + schema.pointer}/#{key}: #{original} #{override}"
          end
        end
      end

      %w[ properties pattern_properties
          type all_of any_of one_of definitions
      ].each do |key|
        override = to_merge.__send__(key)

        unless override.empty?
          original = new_schema.__send__(key)
          if original.empty?
            new_schema.__send__("#{key}=", override)
          elsif original == override
            # Do nothing
          else
            warn "[MERGE] #{schema.id.to_s + schema.pointer}/#{key}: #{original} #{override}"
          end
        end
      end

      new_schema
    end
  end
end
