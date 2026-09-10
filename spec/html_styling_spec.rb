RSpec.describe "add_text HTML styling" do
  NSS = DocxTemplating::NS::DOC

  def html_doc(html)
    document(render(tp("[BODY]")) { |r| r.add_text(:body, html) })
  end

  it "applies text color from inline CSS" do
    doc = html_doc(%(<p>a <span style="color:#FF0000">red</span> b</p>))
    red = doc.xpath("//w:r", NSS).find { |r| r.xpath(".//w:t", NSS).text == "red" }
    expect(red.at_xpath("./w:rPr/w:color", NSS)["w:val"]).to eq("FF0000")
  end

  it "supports rgb(), 3-digit hex, named colors, and <font color>" do
    expect(html_doc(%(<p><span style="color:rgb(0,128,0)">x</span></p>)).at_xpath("//w:color", NSS)["w:val"]).to eq("008000")
    expect(html_doc(%(<p><span style="color:#f00">x</span></p>)).at_xpath("//w:color", NSS)["w:val"]).to eq("FF0000")
    expect(html_doc(%(<p><span style="color:blue">x</span></p>)).at_xpath("//w:color", NSS)["w:val"]).to eq("0000FF")
    expect(html_doc(%(<p><font color="#123456">x</font></p>)).at_xpath("//w:color", NSS)["w:val"]).to eq("123456")
  end

  it "inherits color set on the paragraph itself" do
    doc = html_doc(%(<p style="color:#112233">whole line</p>))
    expect(doc.at_xpath("//w:r/w:rPr/w:color", NSS)["w:val"]).to eq("112233")
  end

  it "applies paragraph alignment (center/right/justify)" do
    aligns = html_doc(%(<p style="text-align:center">c</p><p align="right">r</p><p style="text-align:justify">j</p>))
             .xpath("//w:p", NSS).map { |p| p.at_xpath("./w:pPr/w:jc", NSS)&.[]("w:val") }
    expect(aligns).to eq(%w[center right both])
  end

  it "combines color, bold and alignment" do
    doc = html_doc(%(<p style="text-align:center"><b><span style="color:#00FF00">x</span></b></p>))
    expect(doc.at_xpath("//w:jc", NSS)["w:val"]).to eq("center")
    rpr = doc.at_xpath("//w:r/w:rPr", NSS)
    expect(rpr.at_xpath("./w:b", NSS)).not_to be_nil
    expect(rpr.at_xpath("./w:color", NSS)["w:val"]).to eq("00FF00")
  end

  it "turns <div> blocks into paragraphs" do
    texts = html_doc(%(<div>line one</div><div>line two</div>))
            .xpath("//w:body/w:p", NSS).map { |p| p.xpath(".//w:t", NSS).map(&:text).join }.reject(&:empty?)
    expect(texts).to eq(["line one", "line two"])
  end

  it "maps background-color to run shading and strike-through" do
    doc = html_doc(%(<p><span style="background-color:#FFFF00">hl</span> <s>gone</s></p>))
    expect(doc.at_xpath("//w:shd", NSS)["w:fill"]).to eq("FFFF00")
    expect(doc.at_xpath("//w:strike", NSS)).not_to be_nil
  end

  it "stays well-formed with only WordprocessingML elements" do
    doc = html_doc(%(<p style="text-align:center;color:#ff0000">x <b>y</b></p>))
    expect(doc.errors).to be_empty
    expect(doc.xpath("//w:body//*", NSS).all? { |e| e.namespace&.href == DocxTemplating::NS::W }).to be true
  end

  it "maps padding-left/margin-left to a left indent (twips)" do
    doc = html_doc(%(<p style="padding-left: 40px;">indented</p>))
    expect(doc.at_xpath("//w:p/w:pPr/w:ind", NSS)["w:left"]).to eq("600")
  end

end
