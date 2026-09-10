RSpec.describe DocxTemplating::InlineImage do
  NSI = DocxTemplating::NS::DOC
  let(:png) { ["89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4890000000d4944415478da6364f8cf000000ff00ffa1bdd7e10000000049454e44ae426082"].pack("H*") }

  def with_image(body, **opts)
    Dir.mktmpdir do |dir|
      path = File.join(dir, "photo.png")
      File.binwrite(path, png)
      bytes = render(body) { |r| r.add_inline_image(:photo, path, **opts) }
      parts = entries(bytes)
      yield parts, Nokogiri::XML(parts["word/document.xml"]), path
    end
  end

  it "places the image inline and preserves surrounding text" do
    with_image(tp("Photo: [PHOTO] end")) do |_parts, doc, _|
      para = doc.at_xpath("//w:body/w:p", NSI)
      expect(para.at_xpath(".//w:drawing", NSI)).not_to be_nil
      text = para.xpath(".//w:t", NSI).map(&:text).join
      expect(text).to include("Photo:", "end")
      expect(text).not_to include("[PHOTO]")
    end
  end

  it "embeds the binary and wires the relationship + content type" do
    with_image(tp("[PHOTO]")) do |parts, doc, _|
      expect(parts["word/media/photo.png"]).to eq(png)
      rid = doc.at_xpath("//a:blip/@r:embed", "a" => DocxTemplating::NS::A, "r" => DocxTemplating::NS::R)&.value
      expect(rid).not_to be_nil
      rels = Nokogiri::XML(parts["word/_rels/document.xml.rels"])
      rel = rels.xpath("//*[local-name()='Relationship']").to_a.find { |x| x["Id"] == rid }
      expect(rel && rel["Target"]).to eq("media/photo.png")
      ct = Nokogiri::XML(parts["[Content_Types].xml"])
      expect(ct.xpath("//*[local-name()='Default'][@Extension='png']")).not_to be_empty
    end
  end

  it "converts pixels to EMU at the default 96 dpi (96px -> 1in = 914400 EMU)" do
    with_image(tp("[PHOTO]"), width: 96, height: 96) do |_p, doc, _|
      ext = doc.at_xpath("//wp:extent", "wp" => DocxTemplating::NS::WP)
      expect(ext["cx"]).to eq("914400")
      expect(ext["cy"]).to eq("914400")
    end
  end

  it "honors a custom dpi" do
    with_image(tp("[PHOTO]"), width: 72, dpi: 72) do |_p, doc, _|
      expect(doc.at_xpath("//wp:extent", "wp" => DocxTemplating::NS::WP)["cx"]).to eq("914400")
    end
  end

  it "accepts explicit units (cm -> EMU)" do
    with_image(tp("[PHOTO]"), width: "1cm", height: "2cm") do |_p, doc, _|
      ext = doc.at_xpath("//wp:extent", "wp" => DocxTemplating::NS::WP)
      expect(ext["cx"]).to eq("360000")
      expect(ext["cy"]).to eq("720000")
    end
  end

  it "supports the placeholder appearing more than once" do
    with_image(tp("[PHOTO] and [PHOTO]")) do |_p, doc, _|
      expect(doc.xpath("//w:drawing", NSI).size).to eq(2)
    end
  end

  it "produces well-formed document.xml" do
    with_image(tp("x [PHOTO] y")) { |_p, doc, _| expect(doc.errors).to be_empty }
  end
end
