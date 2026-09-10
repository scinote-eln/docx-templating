RSpec.describe DocxTemplating::Image do
  # 1x1 transparent PNG
  let(:png) { ["89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4890000000d4944415478da6364f8cf000000ff00ffa1bdd7e10000000049454e44ae426082"].pack("H*") }

  it "embeds the image and wires up the relationship and content type" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "logo.png")
      File.binwrite(path, png)

      bytes = render(tp("[LOGO]")) { |r| r.add_image(:logo, path, width: 5, height: 4) }
      parts = entries(bytes)

      expect(parts["word/media/logo.png"]).to eq(png)

      doc = Nokogiri::XML(parts["word/document.xml"])
      rid = doc.at_xpath("//a:blip/@r:embed", "a" => DocxTemplating::NS::A, "r" => DocxTemplating::NS::R)&.value
      expect(rid).not_to be_nil

      rels = Nokogiri::XML(parts["word/_rels/document.xml.rels"])
      rel = rels.xpath("//*[local-name()='Relationship']").to_a.find { |x| x["Id"] == rid }
      expect(rel && rel["Target"]).to eq("media/logo.png")

      ct = Nokogiri::XML(parts["[Content_Types].xml"])
      expect(ct.xpath("//*[local-name()='Default'][@Extension='png']")).not_to be_empty
      expect(doc.errors).to be_empty
    end
  end
end
