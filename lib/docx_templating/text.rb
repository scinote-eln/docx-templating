module DocxTemplating
  # Replaces a placeholder paragraph with HTML-derived paragraphs.
  class Text < Field
    def replace!(doc, _template = nil)
      para = find_placeholder_paragraph(doc)
      return unless para

      build_paragraphs.each { |p| para.before(p) }
      para.remove
    end

    private

    def build_paragraphs
      Parser::Html.new(@data_source.value).paragraphs
    end

    def find_placeholder_paragraph(doc)
      doc.xpath(".//w:p", NS::DOC).find do |p|
        p.xpath(".//w:t", NS::DOC).map(&:text).join.include?(to_placeholder)
      end
    end
  end
end
