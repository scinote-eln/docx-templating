module DocxTemplating
  module Parser
    # Converts an HTML fragment into an array of WordprocessingML paragraph
    # (<w:p>) markup strings.
    class Html
      HEADINGS  = %w[h1 h2 h3 h4 h5 h6].freeze
      LIST_TAGS = %w[ul ol].freeze
      STYLE_TAGS = { "strong" => :b, "b" => :b, "em" => :i, "i" => :i, "u" => :u, "ins" => :u }.freeze
      INDENT_TWIPS = 360 # 0.25" per nesting level

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
          when "p"
            @paragraphs << Wml.paragraph(inline(node))
          when *HEADINGS
            @paragraphs << Wml.paragraph(inline(node), style: "Heading#{node.name[1]}")
          when "ul", "ol"
            build_list(node, ordered: node.name == "ol")
          when "table"
            build_table(node)
          when "text"
            @paragraphs << Wml.paragraph(Wml.run(node.content.delete("\n"))) unless node.text.strip.empty?
          else
            process(node.children) if node.element?
          end
        end
      end

      def build_list(node, ordered:, depth: 0)
        index = 0
        node.children.each do |li|
          next unless li.name == "li"
          index += 1

          nested = li.children.select { |c| LIST_TAGS.include?(c.name) }
          marker = ordered ? "#{index}. " : "\u2022 "
          runs   = Wml.run(("\u00A0" * 2 * depth) + marker) + inline_children(li)

          @paragraphs << Wml.paragraph(runs)
          nested.each { |n| build_list(n, ordered: n.name == "ol", depth: depth + 1) }
        end
      end

      # Inline runs for an element's children (skipping nested block lists).
      def inline_children(node)
        node.children.reject { |c| LIST_TAGS.include?(c.name) }
            .flat_map { |c| inline_node(c, []) }.join
      end

      def inline(node, formats = [])
        node.children.flat_map { |c| inline_node(c, formats) }.join
      end

      def inline_node(node, formats)
        if node.text?
          text = node.content.delete("\n")
          text.empty? ? [] : [Wml.run(text, formats)]
        elsif node.name == "br"
          [Wml.line_break]
        elsif (f = STYLE_TAGS[node.name])
          [inline_runs(node, (formats + [f]).uniq)]
        elsif node.element?
          [inline_runs(node, formats)] # unwrap unknown/foreign tags, keep text
        else
          []
        end
      end

      def inline_runs(node, formats)
        node.children.flat_map { |c| inline_node(c, formats) }.join
      end

      # --- HTML tables ------------------------------------------------------

      TABLE_BORDERS = %w[top left bottom right insideH insideV]
                      .map { |e| %(<w:#{e} w:val="single" w:sz="4" w:space="0" w:color="auto"/>) }.join.freeze
      TABLE_PROPS   = %(<w:tblPr><w:tblW w:w="0" w:type="auto"/><w:tblBorders>#{TABLE_BORDERS}</w:tblBorders></w:tblPr>).freeze
      HEADER_FILL   = "F0F0F6".freeze
      ALIGN         = { "center" => "center", "left" => "left", "right" => "right", "justify" => "both" }.freeze

      def build_table(table)
        rows = table_rows(table)
        return if rows.empty?

        cols = rows.map { |tr| row_width(tr) }.max
        body = rows.map { |tr| build_row(tr) }.join
        grid = "<w:tblGrid>#{'<w:gridCol/>' * cols}</w:tblGrid>"

        @paragraphs << "<w:tbl>#{TABLE_PROPS}#{grid}#{body}</w:tbl>"
        # A table must not be the last block or sit directly before another
        # table, so follow every table with an empty paragraph.
        @paragraphs << "<w:p/>"
      end

      # Rows in document order, pulled from <tr> and from thead/tbody/tfoot
      # sections — but not from tables nested inside a cell.
      def table_rows(table)
        table.children.flat_map do |child|
          case child.name
          when "tr"                     then [child]
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
        align = ALIGN[cell_align(cell)]

        tc_pr = +""
        tc_pr << %(<w:gridSpan w:val="#{span}"/>) if span > 1
        tc_pr << %(<w:shd w:val="clear" w:color="auto" w:fill="#{HEADER_FILL}"/>) if header
        tc_pr = "<w:tcPr>#{tc_pr}</w:tcPr>" unless tc_pr.empty?

        p_pr = align ? %(<w:pPr><w:jc w:val="#{align}"/></w:pPr>) : ""
        runs = inline(cell, header ? [:b] : [])

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

      def cell_align(cell)
        return cell["align"].to_s.downcase if cell["align"]

        cell["style"].to_s[/text-align\s*:\s*([a-z]+)/i, 1]&.downcase
      end
    end
  end
end
