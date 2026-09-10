RSpec.describe DocxTemplating::TableFromData do
  NS = DocxTemplating::NS::DOC

  def render_table(data, body: nil)
    body ||= tp("[REPORT]")
    document(render(body) { |r| r.add_table_from_data(:report, data) })
  end

  let(:data) do
    {
      contents: [["r1c1", "r1c2"], ["r2c1", "r2c2"]],
      columns_title: ["A", "B"],
      cells_attributes: { "0,1" => { style: "text-align:right" } }
    }
  end

  it "builds a table with a header row and one row per record" do
    doc = render_table(data)
    rows = doc.xpath("//w:tbl/w:tr", NS)
    expect(rows.size).to eq(3) # header + 2 data rows
  end

  it "populates cell text" do
    doc = render_table(data)
    cells = doc.xpath("//w:tbl/w:tr/w:tc", NS).map { |c| c.xpath(".//w:t", NS).map(&:text).join }
    expect(cells).to include("A", "B", "r1c1", "r2c2")
  end

  it "styles the header (shading + bold + centered)" do
    doc = render_table(data)
    header = doc.at_xpath("//w:tbl/w:tr[1]", NS)
    expect(header.at_xpath(".//w:shd", NS)["w:fill"]).to eq("F0F0F6")
    expect(header.at_xpath(".//w:b", NS)).not_to be_nil
    expect(header.at_xpath(".//w:jc", NS)["w:val"]).to eq("center")
  end

  it "applies per-cell attributes to body cells" do
    doc = render_table(data)
    # body cell [0,1] -> second row overall (row index 2), second cell
    target = doc.at_xpath("//w:tbl/w:tr[2]/w:tc[2]", NS)
    expect(target.at_xpath(".//w:jc", NS)["w:val"]).to eq("right")
  end

  it "adds rows_title as leading cells and a grid column for it" do
    doc = render_table(data.merge(rows_title: ["one", "two"]))
    first_body = doc.at_xpath("//w:tbl/w:tr[2]/w:tc[1]", NS)
    expect(first_body.xpath(".//w:t", NS).map(&:text).join).to eq("one")
    expect(doc.xpath("//w:tblGrid/w:gridCol", NS).size).to eq(3) # 2 data + 1 title
  end

  it "accepts a JSON string" do
    doc = render_table(JSON.generate(contents: [["x", "y"]], columns_title: ["A", "B"]))
    expect(doc.xpath("//w:tbl/w:tr", NS).size).to eq(2)
  end

  it "replaces the whole paragraph when the placeholder stands alone" do
    doc = render_table(data, body: tp("[REPORT]"))
    expect(doc.xpath("//w:body/w:p", NS)).to be_empty       # no leftover empty paragraph
    expect(doc.xpath("//w:tbl", NS).size).to eq(1)
  end

  it "splits surrounding text into before/after paragraphs (inline)" do
    doc = render_table(data, body: tp("Before [REPORT] after"))
    body_paras = doc.xpath("//w:body/w:p", NS).map { |p| p.xpath(".//w:t", NS).map(&:text).join }
    expect(body_paras).to include(a_string_including("Before"), a_string_including("after"))
    expect(doc.xpath("//w:tbl", NS).size).to eq(1)
  end

  it "removes the placeholder and inserts nothing when contents are empty" do
    doc = render_table({ contents: [] })
    expect(doc.xpath("//w:tbl", NS)).to be_empty
    expect(doc.to_xml).not_to include("[REPORT]")
  end

  it "produces only WordprocessingML elements and well-formed XML" do
    doc = render_table(data)
    foreign = doc.xpath("//w:body//*", NS).reject { |e| e.namespace&.href == DocxTemplating::NS::W }
    expect(foreign).to be_empty
    expect(doc.errors).to be_empty
  end
end
