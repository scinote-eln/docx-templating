RSpec.describe DocxTemplating::Field do
  it "replaces a simple placeholder" do
    doc = document(render(tp("Hello [NAME]")) { |r| r.add_field(:name, "Acme") })
    expect(paragraph_texts(doc)).to eq(["Hello Acme"])
  end

  it "replaces multiple placeholders in one paragraph" do
    doc = document(render(tp("[NAME] owes [AMOUNT]")) do |r|
      r.add_field(:name, "Acme")
      r.add_field(:amount, "$50")
    end)
    expect(paragraph_texts(doc).first).to eq("Acme owes $50")
  end

  it "replaces a placeholder split across runs" do
    body = %(<w:p><w:r><w:t>[NA</w:t></w:r><w:r><w:t>ME]</w:t></w:r></w:p>)
    doc = document(render(body) { |r| r.add_field(:name, "Joined") })
    expect(paragraph_texts(doc).first).to eq("Joined")
  end

  it "produces well-formed document.xml" do
    doc = document(render(tp("[NAME]")) { |r| r.add_field(:name, "x") })
    expect(doc.errors).to be_empty
  end
end
