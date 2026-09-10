module DocxTemplating
  module Composable
    def add_field(name, value = nil, &block)
      fields << Field.new({ name: name, value: value, delimiters: delimiters }, &block)
    end

    def add_text(name, value = nil, &block)
      texts << Text.new({ name: name, value: value, delimiters: delimiters }, &block)
    end

    def add_table_from_data(name, data)
      texts << TableFromData.new({ name: name, value: data, delimiters: delimiters })
    end

    def add_checklist(name, items, opts = {})
      texts << Checklist.new(opts.merge(name: name, value: items, delimiters: delimiters))
    end

    def add_image(name, path = nil, opts = {}, &block)
      images << Image.new(opts.merge(name: name, value: path, delimiters: delimiters), &block)
    end

    def add_inline_image(name, path = nil, width: nil, height: nil, dpi: nil, &block)
      images << InlineImage.new({ name: name, value: path, width: width, height: height,
                                  dpi: dpi, delimiters: delimiters }, &block)
    end

    def add_table(name, collection, opts = {})
      tab = Table.new(opts.merge(name: name, value: collection, delimiters: delimiters))
      tables << tab
      yield(tab)
      tab
    end

    private

    def delimiters
      @delimiters || DocxTemplating.delimiters
    end

    def fields   = @fields   ||= []
    def texts    = @texts    ||= []
    def tables   = @tables   ||= []
    def images   = @images   ||= []
  end
end
