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

      def inline(node)
        node.children.flat_map { |c| inline_node(c, []) }.join
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
    end
  end
end
