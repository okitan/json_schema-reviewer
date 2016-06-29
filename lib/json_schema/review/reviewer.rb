require "json_schema/review"

module JsonSchema::Review
  class Reviewer
    def review(schema)
      errors = []
      errors.push(*review_schema(schema))
      errors.push(*review_links(schema.links))
    end

    def review_schema(schema)
      errors = []

      errors.push(*review_type(schema))

      errors
    end

    # basically
    def review_type(schema)
      errors = []

      position = schema.id.to_s + schema.pointer
      type = schema.type

      level = type.empty? ? "[WARN]" : "[ERROR]"

      # validation keywords for number and integer
      unless type.include?("number") && type.include?("integer")
        %w[ multiple_of min min_exclusive max max_exclusive ].each do |key|
           if schema.__send__(key)
             key = convert_key(key).sub("min", "minimum").sub("max", "maximum")
             errors.push("#{level} #{position}/#{key} is defined but type does not include number or integer")
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

    def convert_key(key)
      key.gsub(/_(\w)/) { $1.upcase }
    end
  end
end
