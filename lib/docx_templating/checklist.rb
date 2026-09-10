module DocxTemplating
  # Renders a checklist: one paragraph per item, prefixed with a checkbox glyph
  # (☑ checked / ☐ unchecked). No real list, so no bullet appears beside the glyph.
  class Checklist < Text
    DEFAULT_CHECKED   = "\u2611".freeze
    DEFAULT_UNCHECKED = "\u2610".freeze

    def initialize(opts, &block)
      @checked_symbol   = opts[:checked_symbol]   || DEFAULT_CHECKED
      @unchecked_symbol = opts[:unchecked_symbol] || DEFAULT_UNCHECKED
      super
    end

    private

    def build_paragraphs
      Array(@data_source.value).map do |item|
        checked, text = normalize(item)
        symbol = checked ? @checked_symbol : @unchecked_symbol
        Wml.paragraph(Wml.run("#{symbol} #{text}"))
      end
    end

    def normalize(item)
      case item
      when Hash
        h = item.transform_keys(&:to_sym)
        [truthy?(h[:checked]), h[:text].to_s]
      when Array
        [truthy?(item[1]), item[0].to_s]
      else
        if item.respond_to?(:text) && item.respond_to?(:checked)
          [truthy?(item.checked), item.text.to_s]
        else
          [false, item.to_s]
        end
      end
    end

    def truthy?(value)
      return false if value.nil? || value == false
      return false if %w[false 0 no n].include?(value.to_s.strip.downcase)
      true
    end
  end
end
