RSpec.describe DocxTemplating::Text do
  def render_html(html)
    document(render(tp("[BODY]")) { |r| r.add_text(:body, html) })
  end

  it "renders paragraphs with inline bold" do
    doc = render_html("<p>Intro <strong>bold</strong></p>")
    expect(paragraph_texts(doc)).to include("Intro bold")
    expect(doc.xpath("//w:b", DocxTemplating::NS::DOC)).not_to be_empty
  end

  it "maps headings to Word heading styles" do
    doc = render_html("<h2>Title</h2>")
    expect(doc.at_xpath("//w:pStyle[@w:val='Heading2']", DocxTemplating::NS::DOC)).not_to be_nil
  end

  it "renders unordered list items with bullets" do
    doc = render_html("<ul><li>a</li><li>b</li></ul>")
    texts = paragraph_texts(doc)
    expect(texts).to include("\u2022 a", "\u2022 b")
  end

  it "renders ordered lists with numbers" do
    doc = render_html("<ol><li>one</li><li>two</li></ol>")
    texts = paragraph_texts(doc)
    expect(texts).to include("1. one", "2. two")
  end

  it "indents nested lists" do
    doc = render_html("<ul><li>top<ul><li>nested</li></ul></li></ul>")
    expect(paragraph_texts(doc)).to include("\u00A0\u00A0\u2022 nested")
  end

  it "produces only WordprocessingML elements (no foreign tags)" do
    doc = render_html("<p>see <a href='#'>link</a> &amp; <span>more</span></p>")
    foreign = doc.xpath("//w:body//*", DocxTemplating::NS::DOC).reject { |e| e.namespace&.href == DocxTemplating::NS::W }
    expect(foreign).to be_empty
  end

  it "unwraps foreign tags and decodes entities" do
    doc = render_html("<p>see <a href='#'>link</a> &amp; more</p>")
    expect(paragraph_texts(doc)).to include("see link & more")
  end
end
