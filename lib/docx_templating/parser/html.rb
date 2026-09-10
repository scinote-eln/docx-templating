module DocxTemplating
  module Parser
    # Converts an HTML fragment into an array of WordprocessingML block markup
    # strings (paragraphs and tables). Known inline tags and inline CSS become
    # run/paragraph properties; unknown tags are unwrapped (text kept); text is
    # taken decoded so no HTML entity or foreign tag reaches the XML.
    class Html
      HEADINGS   = %w[h1 h2 h3 h4 h5 h6].freeze
      LIST_TAGS  = %w[ul ol].freeze
      BLOCK_TAGS = (%w[p div blockquote ul ol table section article header footer figure figcaption pre address] + HEADINGS).freeze
      STYLE_TAGS = { "strong" => :b, "b" => :b, "em" => :i, "i" => :i, "u" => :u, "ins" => :u, "s" => :strike, "strike" => :strike, "del" => :strike }.freeze
      ALIGN      = { "center" => "center", "left" => "left", "right" => "right", "justify" => "both" }.freeze

      NAMED_COLORS = {
        "black" => "000000", "white" => "FFFFFF", "red" => "FF0000", "green" => "008000",
        "blue" => "0000FF", "yellow" => "FFFF00", "orange" => "FFA500", "purple" => "800080",
        "gray" => "808080", "grey" => "808080", "silver" => "C0C0C0", "maroon" => "800000",
        "navy" => "000080", "teal" => "008080", "lime" => "00FF00", "aqua" => "00FFFF",
        "fuchsia" => "FF00FF", "olive" => "808000"
      }.freeze

      attr_reader :paragraphs

      def initialize(text)
        @text = text.to_s
        @paragraphs = []
        parse
      end

      private

      def parse
        process(Nokogiri::HTML5.fragment(@text).children)
      end

      def process(nodes)
        nodes.each do |node|
          case node.name
          when "ul", "ol" then build_list(node, ordered: node.name == "ol")
          when "table"    then build_table(node)
          when "text"
            @paragraphs << Wml.paragraph(Wml.run(node.content.delete("\n"))) unless node.text.strip.empty?
          when *BLOCK_TAGS then emit_block(node)
          else
            node.element? ? emit_block(node) : nil
          end
        end
      end

      # A block element becomes one paragraph unless it contains block children,
      # in which case we descend (e.g. a <div> wrapping several <p>).
      def emit_block(node)
        if node.children.any? { |c| BLOCK_TAGS.include?(c.name) }
          process(node.children)
        else
          @paragraphs << Wml.paragraph(inline(node, element_props(node)),
                                       style: heading_style(node), align: align_of(node),
                                       indent: indent_of(node))
        end
      end

      def heading_style(node)
        "Heading#{node.name[1]}" if HEADINGS.include?(node.name)
      end

      def align_of(node)
        raw = node["align"] || node["style"].to_s[/text-align\s*:\s*([a-z]+)/i, 1]
        ALIGN[raw&.downcase]
      end

      # Left indent (twips) from padding-left / margin-left.
      def indent_of(node)
        style = node["style"].to_s
        raw = style[/(?:padding-left|margin-left)\s*:\s*([^;]+)/i, 1]
        length_to_twips(raw)
      end

      TWIPS_PER_UNIT = { "px" => 15.0, "pt" => 20.0, "cm" => 566.9, "mm" => 56.69, "in" => 1440.0, "" => 15.0 }.freeze

      def length_to_twips(value)
        return nil unless value && (m = value.strip.match(/\A([\d.]+)\s*(px|pt|cm|mm|in)?\z/i))

        (m[1].to_f * TWIPS_PER_UNIT[(m[2] || "").downcase]).round
      end

      def build_list(node, ordered:, depth: 0)
        index = 0
        node.children.each do |li|
          next unless li.name == "li"
          index += 1

          nested = li.children.select { |c| LIST_TAGS.include?(c.name) }
          marker = ordered ? "#{index}. " : "\u2022 "
          runs   = Wml.run(("\u00A0" * 2 * depth) + marker) + inline_children(li)

          @paragraphs << Wml.paragraph(runs, align: align_of(li))
          nested.each { |n| build_list(n, ordered: n.name == "ol", depth: depth + 1) }
        end
      end

      # --- inline runs ------------------------------------------------------

      def inline(node, props = {})
        node.children.flat_map { |c| inline_node(c, props) }.join
      end

      def inline_children(node)
        node.children.reject { |c| LIST_TAGS.include?(c.name) }
            .flat_map { |c| inline_node(c, {}) }.join
      end

      def inline_node(node, props)
        if node.text?
          text = node.content.delete("\n")
          text.empty? ? [] : [Wml.run(text, props)]
        elsif node.name == "br"
          [Wml.line_break]
        elsif node.element?
          [inline(node, props.merge(element_props(node)))]
        else
          []
        end
      end

      # Character properties contributed by an element (tag + inline CSS).
      def element_props(node)
        props = {}
        props[STYLE_TAGS[node.name]] = true if STYLE_TAGS.key?(node.name)

        style = node["style"].to_s
        props[:b]      = true if style =~ /font-weight\s*:\s*(bold|[6-9]00)/i
        props[:i]      = true if style =~ /font-style\s*:\s*italic/i
        props[:u]      = true if style =~ /text-decoration[^;]*underline/i
        props[:strike] = true if style =~ /text-decoration[^;]*line-through/i

        if (c = style[/(?:^|;)\s*color\s*:\s*([^;]+)/i, 1] || (node.name == "font" ? node["color"] : nil))
          hex = css_color(c)
          props[:color] = hex if hex
        end
        if (bg = style[/background(?:-color)?\s*:\s*([^;]+)/i, 1])
          hex = css_color(bg)
          props[:shd] = hex if hex
        end
        props
      end

      # Normalize a CSS colour to a 6-digit uppercase hex, or nil.
      def css_color(value)
        v = value.to_s.strip.downcase
        return NAMED_COLORS[v] if NAMED_COLORS.key?(v)

        if (m = v.match(/\A#?([0-9a-f]{3})\z/))
          return m[1].chars.map { |c| c * 2 }.join.upcase
        end
        if (m = v.match(/\A#?([0-9a-f]{6})\z/))
          return m[1].upcase
        end
        if (m = v.match(/\Argba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)/))
          return m[1..3].map { |n| format("%02X", n.to_i.clamp(0, 255)) }.join
        end
        nil
      end

      # --- HTML tables ------------------------------------------------------

      TABLE_BORDERS = %w[top left bottom right insideH insideV]
                      .map { |e| %(<w:#{e} w:val="single" w:sz="4" w:space="0" w:color="auto"/>) }.join.freeze
      HEADER_FILL   = "F0F0F6".freeze
      CONTENT_TWIPS = 9360 # ~6.5" usable page width

      def build_table(table)
        rows = table_rows(table)
        return if rows.empty?

        cols   = rows.map { |tr| row_width(tr) }.max
        widths = column_twips(table, cols)
        grid   = "<w:tblGrid>#{widths.map { |w| w ? %(<w:gridCol w:w="#{w}"/>) : '<w:gridCol/>' }.join}</w:tblGrid>"
        body   = rows.map { |tr| build_row(tr) }.join

        @paragraphs << "<w:tbl>#{table_props(table)}#{grid}#{body}</w:tbl>"
        @paragraphs << "<w:p/>"
      end

      def table_props(table)
        pct = table["style"].to_s[/(?:^|;)\s*width\s*:\s*([\d.]+)%/i, 1]
        tbl_w = pct ? %(w:w="#{(pct.to_f * 50).round}" w:type="pct") : %(w:w="0" w:type="auto")
        %(<w:tblPr><w:tblW #{tbl_w}/><w:tblBorders>#{TABLE_BORDERS}</w:tblBorders></w:tblPr>)
      end

      # Per-column widths in twips (or an array of nils for auto sizing).
      def column_twips(table, cols)
        pcts = colgroup_percents(table)
        return Array.new(cols) if pcts.nil? || pcts.empty?

        pcts = pcts.first(cols)
        pcts += Array.new(cols - pcts.size, 100.0 / cols) if pcts.size < cols
        total = pcts.sum
        total.zero? ? Array.new(cols) : pcts.map { |p| ((p / total) * CONTENT_TWIPS).round }
      end

      def colgroup_percents(table)
        cols = table.xpath("./colgroup/col")
        return nil if cols.empty?

        cols.map { |c| c["style"].to_s[/width\s*:\s*([\d.]+)%/i, 1]&.to_f || (100.0 / cols.size) }
      end

      def table_rows(table)
        table.children.flat_map do |child|
          case child.name
          when "tr"                      then [child]
          when "thead", "tbody", "tfoot" then child.xpath("./tr").to_a
          else []
          end
        end
      end

      def row_width(tr)
        cells(tr).sum { |c| colspan(c) }
      end

      def build_row(tr)
        header = header_row?(tr)
        "<w:tr>#{cells(tr).map { |c| build_cell(c, header || c.name == 'th') }.join}</w:tr>"
      end

      def build_cell(cell, header)
        span  = colspan(cell)
        align = align_of(cell)

        tc_pr = +""
        tc_pr << %(<w:gridSpan w:val="#{span}"/>) if span > 1
        tc_pr << %(<w:shd w:val="clear" w:color="auto" w:fill="#{HEADER_FILL}"/>) if header
        tc_pr = "<w:tcPr>#{tc_pr}</w:tcPr>" unless tc_pr.empty?

        p_pr = align ? %(<w:pPr><w:jc w:val="#{align}"/></w:pPr>) : ""
        base = element_props(cell)
        base[:b] = true if header
        runs = inline(cell, base)

        "<w:tc>#{tc_pr}<w:p>#{p_pr}#{runs}</w:p></w:tc>"
      end

      def cells(tr)
        tr.xpath("./th|./td").to_a
      end

      def colspan(cell)
        [cell["colspan"].to_i, 1].max
      end

      def header_row?(tr)
        tr.parent&.name == "thead" || (cells(tr).any? && cells(tr).all? { |c| c.name == "th" })
      end
    end
  end
end
