module DocxTemplating
  # Repeats a template table row for each record in a collection.
  # The template row is located by the placeholders of its columns.
  class Table
    def initialize(opts)
      @name = opts[:name]
      @delimiters = opts[:delimiters] || DocxTemplating.delimiters
      @data_source = DataSource.new(opts)
      @columns = []
    end

    def add_column(name, value = nil, &block)
      @columns << Field.new({ name: name, value: value, delimiters: @delimiters }, &block)
      self
    end

    def replace!(doc, _template = nil)
      row = find_template_row(doc)
      return unless row

      Array(@data_source.value).each do |record|
        new_row = row.dup
        @columns.each { |col| col.set_source(record).replace!(new_row) }
        row.before(new_row)
      end

      row.remove
    end

    private

    def find_template_row(doc)
      return nil if @columns.empty?
      marker = @columns.first.to_placeholder
      doc.xpath(".//w:tr", NS::DOC).find do |tr|
        tr.xpath(".//w:t", NS::DOC).map(&:text).join.include?(marker)
      end
    end
  end
end
