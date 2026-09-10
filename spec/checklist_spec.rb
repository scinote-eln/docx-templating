RSpec.describe DocxTemplating::Checklist do
  subject(:texts) do
    paragraph_texts(document(render(tp("[TASKS]")) do |r|
      r.add_checklist(:tasks, items, opts)
    end))
  end
  let(:opts) { {} }

  context "with mixed item shapes" do
    let(:items) { [{ text: "Done", checked: true }, { text: "Todo", checked: false }, ["arr", true], "bare"] }

    it { expect(texts[0]).to start_with("\u2611 Done") }
    it { expect(texts[1]).to start_with("\u2610 Todo") }
    it { expect(texts[2]).to start_with("\u2611 arr") }
    it { expect(texts[3]).to start_with("\u2610 bare") }
  end

  context "with falsey checked values" do
    let(:items) { [["a", "false"], ["b", 0], ["c", nil]] }
    it "treats them as unchecked" do
      expect(texts).to all(start_with("\u2610 "))
    end
  end

  context "with custom symbols" do
    let(:items) { [{ text: "x", checked: true }, { text: "y", checked: false }] }
    let(:opts)  { { checked_symbol: "[x]", unchecked_symbol: "[ ]" } }

    it { expect(texts[0]).to start_with("[x] ") }
    it { expect(texts[1]).to start_with("[ ] ") }
  end

  it "emits no list (no bullet beside the glyph)" do
    doc = document(render(tp("[TASKS]")) { |r| r.add_checklist(:tasks, ["one"]) })
    expect(doc.xpath("//w:numPr", DocxTemplating::NS::DOC)).to be_empty
  end
end
