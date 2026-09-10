module DocxTemplating
  # Plain text placeholder replacement.
  #
  # In .docx a placeholder typed in Word is frequently split across several
  # <w:r>/<w:t> runs. We therefore join the text of all <w:t> in each paragraph,
  # replace there, write the result into the first <w:t>, and blank the rest —
  # which reliably handles split placeholders.
  class Field
    def initialize(opts, &block)
      @name = opts[:name]
      @delimiters = opts[:delimiters] || DocxTemplating.delimiters
      @data_source = DataSource.new(opts, &block)
    end

    def set_source(record)
      @data_source.set_source(record)
      self
    end

    def replace!(scope)
      value = sanitize(@data_source.value)
      Field.substitute(scope, to_placeholder, value)
    end

    # Run-merge substitution of `placeholder` -> `value` within every <w:p>
    # under `scope` (the whole document, a table row, etc.).
    def self.substitute(scope, placeholder, value)
      scope.xpath(".//w:p", NS::DOC).each do |para|
        t_nodes = para.xpath(".//w:t", NS::DOC)
        next if t_nodes.empty?

        joined = t_nodes.map(&:text).join
        next unless joined.include?(placeholder)

        replaced = joined.gsub(placeholder, value.to_s)
        t_nodes.first.content = replaced
        t_nodes.first["xml:space"] = "preserve"
        t_nodes.drop(1).each { |t| t.content = "" }
      end
    end

    def to_placeholder
      open, close = @delimiters
      "#{open}#{@name.to_s.upcase}#{close}"
    end

    private

    def sanitize(value)
      value.to_s
    end
  end
end
