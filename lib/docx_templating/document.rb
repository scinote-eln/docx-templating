module DocxTemplating
  class Document
    include Composable

    def initialize(template_path = nil, io: nil, delimiters: nil)
      @template = Template.new(template_path, io: io)
      @delimiters = delimiters && DocxTemplating.normalize_delimiters(delimiters)
      yield(self) if block_given?
    end

    def configure
      yield(self) if block_given?
      self
    end

    def generate(dest = nil)
      bytes = @template.update do |doc|
        tables.each  { |c| c.replace!(doc, @template) }
        texts.each   { |c| c.replace!(doc, @template) }
        images.each  { |c| c.replace!(doc, @template) }
        fields.each  { |c| c.replace!(doc) }
      end

      File.binwrite(dest, bytes) if dest
      bytes
    end
  end
end
