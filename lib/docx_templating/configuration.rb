module DocxTemplating
  #   DocxTemplating.delimiters = :square   # [NAME]   (default)
  #   DocxTemplating.delimiters = :curly    # {{NAME}}
  #   DocxTemplating.delimiters = ["((", "))"]
  module Configuration
    SQUARE = ["[", "]"].freeze
    CURLY  = ["{{", "}}"].freeze
    PRESETS = { square: SQUARE, curly: CURLY, braces: CURLY }.freeze

    def delimiters
      @delimiters ||= SQUARE.dup
    end

    def delimiters=(value)
      @delimiters = normalize_delimiters(value)
    end

    def normalize_delimiters(value)
      case value
      when Symbol, String
        PRESETS[value.to_sym] ||
          raise(ArgumentError, "Unknown delimiter preset #{value.inspect}; use :square, :curly, or a two-element array")
      when Array
        unless value.size == 2 && value.all? { |v| v.is_a?(String) && !v.empty? }
          raise ArgumentError, "delimiters must be a two-element array of non-empty strings, got #{value.inspect}"
        end
        value.map(&:dup).freeze
      else
        raise ArgumentError, "delimiters must be a Symbol preset or a two-element array, got #{value.class}"
      end
    end
  end

  extend Configuration
end
