RSpec.describe DocxTemplating::Table do
  let(:body) do
    header = %(<w:tr><w:tc>#{tp("Product")}</w:tc><w:tc>#{tp("Price")}</w:tc></w:tr>)
    row    = %(<w:tr><w:tc>#{tp("[PRODUCT]")}</w:tc><w:tc>#{tp("[PRICE]")}</w:tc></w:tr>)
    %(<w:tbl>#{header}#{row}</w:tbl>)
  end

  subject(:doc) do
    document(render(body) do |r|
      r.add_table(:items, [{ product: "Widget", price: "10" }, { product: "Gadget", price: "20" }]) do |t|
        t.add_column(:product)
        t.add_column(:price)
      end
    end)
  end

  it "repeats the template row per record (plus header)" do
    expect(doc.xpath("//w:tbl/w:tr", DocxTemplating::NS::DOC).size).to eq(3)
  end

  it "populates each row from its record" do
    cells = doc.xpath("//w:tbl/w:tr", DocxTemplating::NS::DOC).map { |tr| tr.xpath(".//w:t", DocxTemplating::NS::DOC).map(&:text).join(" ") }
    expect(cells).to include(a_string_including("Widget", "10"), a_string_including("Gadget", "20"))
  end

  it "leaves no placeholders behind" do
    expect(doc.to_xml).not_to include("[PRODUCT]", "[PRICE]")
  end
end
