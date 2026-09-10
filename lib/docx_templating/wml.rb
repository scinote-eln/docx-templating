module DocxTemplating
  # Helpers for building WordprocessingML markup strings.
  module Wml
    module_function

    XML_ESCAPE = { "&" => "&amp;", "<" => "&lt;", ">" => "&gt;", '"' => "&quot;" }.freeze

    def escape(text)
      text.to_s.gsub(/[&<>"]/, XML_ESCAPE)
    end

    # A run with optional character formatting (set of :b, :i, :u symbols).
    def run(text, formats = [])
      props = formats.map { |f| "<w:#{f}/>" }.join
      rpr = props.empty? ? "" : "<w:rPr>#{props}</w:rPr>"
      %(<w:r>#{rpr}<w:t xml:space="preserve">#{escape(text)}</w:t></w:r>)
    end

    def line_break
      "<w:r><w:br/></w:r>"
    end

    # A paragraph, optionally with a paragraph style id (w:pStyle).
    def paragraph(inner, style: nil)
      ppr = style ? %(<w:pPr><w:pStyle w:val="#{escape(style)}"/></w:pPr>) : ""
      %(<w:p>#{ppr}#{inner}</w:p>)
    end
  end
end
