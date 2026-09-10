RSpec.describe DocxTemplating::Configuration do
  around do |example|
    saved = DocxTemplating.delimiters
    example.run
    DocxTemplating.delimiters = saved
  end

  it "defaults to square brackets" do
    doc = document(render(tp("[NAME]")) { |r| r.add_field(:name, "x") })
    expect(paragraph_texts(doc).first).to eq("x")
  end

  it "accepts a per-document :curly override" do
    doc = document(render(tp("{{NAME}}"), delimiters: :curly) { |r| r.add_field(:name, "Curly") })
    expect(paragraph_texts(doc).first).to eq("Curly")
  end

  it "does not leak the per-document override to the global default" do
    render(tp("{{NAME}}"), delimiters: :curly) { |r| r.add_field(:name, "x") }
    expect(DocxTemplating.delimiters).to eq(["[", "]"])
  end

  it "honors a global default" do
    DocxTemplating.delimiters = :curly
    doc = document(render(tp("{{NAME}}")) { |r| r.add_field(:name, "Global") })
    expect(paragraph_texts(doc).first).to eq("Global")
  end

  it "rejects invalid delimiters" do
    expect { DocxTemplating.delimiters = :nope }.to raise_error(ArgumentError)
    expect { DocxTemplating.delimiters = ["only"] }.to raise_error(ArgumentError)
  end
end
