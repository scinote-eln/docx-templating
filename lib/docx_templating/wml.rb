module DocxTemplating
  # Helpers for building WordprocessingML markup strings.
  module Wml
    module_function

    XML_ESCAPE = { "&" => "&amp;", "<" => "&lt;", ">" => "&gt;", '"' => "&quot;" }.freeze

    def escape(text)
      text.to_s.gsub(/[&<>"]/, XML_ESCAPE)
    end

    # A run with optional character formatting. `props` may be a Hash of
    # properties (:b, :i, :u booleans; :color, :shd as 6-digit hex) or, for
    # backward compatibility, an Array of symbols (e.g. [:b, :i]).
    def run(text, props = {})
      %(<w:r>#{run_properties(props)}<w:t xml:space="preserve">#{escape(text)}</w:t></w:r>)
    end

    def run_properties(props)
      props = symbolize(props)
      parts = +""
      parts << "<w:b/>"                        if props[:b]
      parts << "<w:i/>"                        if props[:i]
      parts << %(<w:u w:val="single"/>)        if props[:u]
      parts << %(<w:strike/>)                  if props[:strike]
      parts << %(<w:color w:val="#{props[:color]}"/>) if props[:color]
      parts << %(<w:shd w:val="clear" w:color="auto" w:fill="#{props[:shd]}"/>) if props[:shd]
      parts.empty? ? "" : "<w:rPr>#{parts}</w:rPr>"
    end

    def symbolize(props)
      return props if props.is_a?(Hash)

      Array(props).each_with_object({}) { |s, h| h[s] = true }
    end

    def line_break
      "<w:r><w:br/></w:r>"
    end

    # A paragraph, optionally with a paragraph style id (w:pStyle),
    # justification (w:jc), and left indent in twips (w:ind).
    def paragraph(inner, style: nil, align: nil, indent: nil)
      props = +""
      props << %(<w:pStyle w:val="#{escape(style)}"/>) if style
      props << %(<w:ind w:left="#{indent}"/>)          if indent && indent > 0
      props << %(<w:jc w:val="#{align}"/>)             if align
      ppr = props.empty? ? "" : "<w:pPr>#{props}</w:pPr>"
      %(<w:p>#{ppr}#{inner}</w:p>)
    end
  end
end
