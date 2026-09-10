RSpec.describe "add_text with HTML tables" do
  NST = DocxTemplating::NS::DOC

  def render_html(html)
    document(render(tp("[BODY]")) { |r| r.add_text(:body, html) })
  end

  it "converts <table> into a w:tbl instead of dropping it" do
    doc = render_html("<table><tr><td>a</td><td>b</td></tr><tr><td>c</td><td>d</td></tr></table>")
    expect(doc.xpath("//w:tbl", NST).size).to eq(1)
    expect(doc.xpath("//w:tbl/w:tr", NST).size).to eq(2)
    cells = doc.xpath("//w:tbl//w:tc", NST).map { |c| c.xpath(".//w:t", NST).map(&:text).join }
    expect(cells).to eq(%w[a b c d])
  end

  it "styles header cells (th / thead) bold and shaded" do
    doc = render_html("<table><thead><tr><th>H1</th><th>H2</th></tr></thead><tbody><tr><td>x</td><td>y</td></tr></tbody></table>")
    header = doc.at_xpath("//w:tbl/w:tr[1]", NST)
    expect(header.at_xpath(".//w:b", NST)).not_to be_nil
    expect(header.at_xpath(".//w:shd", NST)["w:fill"]).to eq("F0F0F6")
  end

  it "keeps inline formatting inside cells" do
    doc = render_html("<table><tr><td>plain <strong>bold</strong></td></tr></table>")
    cell = doc.at_xpath("//w:tbl//w:tc", NST)
    expect(cell.xpath(".//w:t", NST).map(&:text).join).to eq("plain bold")
    expect(cell.at_xpath(".//w:b", NST)).not_to be_nil
  end

  it "maps colspan to w:gridSpan and honors alignment" do
    doc = render_html("<table><tr><td colspan='2' align='center'>wide</td></tr></table>")
    expect(doc.at_xpath("//w:gridSpan", NST)["w:val"]).to eq("2")
    expect(doc.at_xpath("//w:tbl//w:jc", NST)["w:val"]).to eq("center")
  end

  it "preserves paragraphs and tables around it, in order" do
    doc = render_html("<p>Before</p><table><tr><td>x</td></tr></table><p>After</p>")
    names = doc.xpath("//w:body/*", NST).map(&:name)
    expect(names.first).to eq("p")     # "Before"
    expect(names).to include("tbl")
    expect(names.last).to eq("p")      # "After" (or trailing empty p)
    texts = doc.xpath("//w:body/w:p", NST).map { |p| p.xpath(".//w:t", NST).map(&:text).join }
    expect(texts).to include("Before", "After")
  end

  it "produces only WordprocessingML and well-formed XML" do
    doc = render_html("<table><tr><td>a</td></tr></table>")
    foreign = doc.xpath("//w:body//*", NST).reject { |e| e.namespace&.href == DocxTemplating::NS::W }
    expect(foreign).to be_empty
    expect(doc.errors).to be_empty
  end

  it "honors table and column width percentages" do
    html = "<table style='width:99.9761%'><colgroup><col style='width:30%'><col style='width:70%'></colgroup><tr><td>a</td><td>b</td></tr></table>"
    doc = document(render(tp("[BODY]")) { |r| r.add_text(:body, html) })
    expect(doc.at_xpath("//w:tblW", NST)["w:type"]).to eq("pct")
    expect(doc.at_xpath("//w:tblW", NST)["w:w"]).to eq("4999")
    widths = doc.xpath("//w:tblGrid/w:gridCol", NST).map { |c| c["w:w"].to_i }
    expect((widths[1].to_f / widths[0]).round(1)).to eq(2.3)
  end

end
