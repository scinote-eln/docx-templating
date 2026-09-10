require "json"

module DocxTemplating
  # Inserts a table built from structured (JSON) data at a text placeholder.
  #
  #   report.add_table_from_data(:report, {
  #     contents:      [[1, 2, 4], ["res", 2, 1]],   # required: rows of cells
  #     columns_title: ["A", "test", "C"],            # optional header row
  #     rows_title:    [1, 2],                          # optional leading label per row
  #     cells_attributes: {                             # optional per-body-cell styling
  #       "0,0" => { style: "text-align:center;font-weight:bold" }
  #     },
  #     table_name: "Results"                           # optional (accepted, not rendered)
  #   })
  #
  # `value` may be the Hash above or a JSON string. When the placeholder is the
  # whole paragraph it is replaced by the table; when it sits inside other text
  # the paragraph is split into before-text / table / after-text (Word tables
  # are block-level, so "inline" means splitting the surrounding paragraph).
  #
  # Supported style declarations (CSS-like, per cell): text-align (left/center/
  # right/justify), vertical-align (top/middle/bottom), font-weight:bold,
  # font-style:italic, text-decoration:underline, background-color:#rrggbb.
  class TableFromData < Text
    HEADER_STYLE = "background-color:#F0F0F6;text-align:center;vertical-align:middle;font-weight:bold".freeze

    JC     = { "center" => "center", "left" => "left", "right" => "right", "justify" => "both" }.freeze
    VALIGN = { "middle" => "center", "center" => "center", "top" => "top", "bottom" => "bottom" }.freeze

    def initialize(opts, &block)
      super
      data = parse_data(@data_source.value)
      @contents         = data[:contents] || []
      @columns_title    = data[:columns_title]
      @rows_title       = data[:rows_title]
      @cells_attributes = normalize_cells(data[:cells_attributes])
    end

    def replace!(doc, _template = nil)
      para = find_placeholder_paragraph(doc)
      return unless para

      if @contents.empty?
        para.remove
        return
      end

      joined = para.xpath(".//w:t", NS::DOC).map(&:text).join
      before, after = joined.split(to_placeholder, 2)

      para.before(paragraph_with(before))  if before && !before.strip.empty?
      para.before(build_table)
      para.before(paragraph_with(after))   if after && !after.strip.empty?
      para.remove
    end

    private

    def paragraph_with(text)
      Wml.paragraph(Wml.run(text))
    end

    def data_columns
      (@contents.map(&:length) + [@columns_title&.length].compact).max.to_i
    end

    def build_table
      cols = data_columns
      lead = @rows_title ? 1 : 0
      total = cols + lead

      rows = +""
      rows << header_row(cols, lead) if @columns_title
      @contents.each_with_index { |row, i| rows << body_row(row, i, cols, lead) }

      grid = "<w:tblGrid>#{'<w:gridCol/>' * total}</w:tblGrid>"
      "<w:tbl>#{table_props}#{grid}#{rows}</w:tbl>"
    end

    def table_props
      border = %w[top left bottom right insideH insideV]
               .map { |e| %(<w:#{e} w:val="single" w:sz="4" w:space="0" w:color="auto"/>) }.join
      %(<w:tblPr><w:tblW w:w="0" w:type="auto"/><w:tblBorders>#{border}</w:tblBorders></w:tblPr>)
    end

    def header_row(cols, lead)
      cells = +""
      cells << cell("", HEADER_STYLE) if lead == 1
      cols.times { |j| cells << cell(@columns_title[j], HEADER_STYLE) }
      "<w:tr>#{cells}</w:tr>"
    end

    def body_row(row, row_index, cols, lead)
      cells = +""
      cells << cell(@rows_title[row_index], HEADER_STYLE) if lead == 1
      cols.times { |j| cells << cell(row[j], @cells_attributes[[row_index, j]]) }
      "<w:tr>#{cells}</w:tr>"
    end

    def cell(value, style)
      props = parse_style(style)

      tc_pr = +""
      if (bg = props["background-color"])
        tc_pr << %(<w:shd w:val="clear" w:color="auto" w:fill="#{hex(bg)}"/>)
      end
      if (va = VALIGN[props["vertical-align"]])
        tc_pr << %(<w:vAlign w:val="#{va}"/>)
      end
      tc_pr = "<w:tcPr>#{tc_pr}</w:tcPr>" unless tc_pr.empty?

      p_pr = ""
      if (jc = JC[props["text-align"]])
        p_pr = %(<w:pPr><w:jc w:val="#{jc}"/></w:pPr>)
      end

      r_pr = +""
      r_pr << "<w:b/>" if props["font-weight"] == "bold"
      r_pr << "<w:i/>" if props["font-style"] == "italic"
      r_pr << %(<w:u w:val="single"/>) if props["text-decoration"].to_s.include?("underline")
      r_pr = "<w:rPr>#{r_pr}</w:rPr>" unless r_pr.empty?

      "<w:tc>#{tc_pr}<w:p>#{p_pr}#{runs(value, r_pr)}</w:p></w:tc>"
    end

    def runs(value, r_pr)
      value.to_s.split("\n", -1)
           .map { |seg| %(<w:r>#{r_pr}<w:t xml:space="preserve">#{Wml.escape(seg)}</w:t></w:r>) }
           .join("<w:r><w:br/></w:r>")
    end

    def parse_style(style)
      style.to_s.split(";").each_with_object({}) do |decl, h|
        key, val = decl.split(":", 2)
        h[key.strip.downcase] = val.strip.downcase if key && val
      end
    end

    def hex(color)
      color.to_s.strip.sub(/\A#/, "").upcase
    end

    def parse_data(value)
      hash = value.is_a?(String) ? JSON.parse(value) : (value || {})
      hash.each_with_object({}) { |(k, v), h| h[k.to_sym] = v }
    end

    def normalize_cells(attrs)
      return {} unless attrs.is_a?(Hash)

      attrs.each_with_object({}) do |(k, v), h|
        key = case k
              when Array  then k.map(&:to_i)
              when String then k.split(/[,\-]/).map(&:to_i)
              else next
              end
        h[key] = v.is_a?(Hash) ? (v[:style] || v["style"]) : v
      end
    end
  end
end
