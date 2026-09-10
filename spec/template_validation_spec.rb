RSpec.describe DocxTemplating::Template do
  def generate_from(io)
    DocxTemplating::Report.new(io: io) { |r| r.add_field(:x, "y") }.generate
  end

  it "raises a clear error for a non-Zip file (e.g. legacy .doc)" do
    doc_magic = "\xD0\xCF\x11\xE0".b + ("\x00" * 40)
    expect { generate_from(doc_magic) }
      .to raise_error(DocxTemplating::InvalidTemplate, /not a Zip\/OOXML/)
  end

  it "raises for an empty / truncated file" do
    expect { generate_from("") }.to raise_error(DocxTemplating::InvalidTemplate, /empty or truncated/)
    expect { generate_from("PK") }.to raise_error(DocxTemplating::InvalidTemplate, /empty or truncated/)
  end

  it "raises for HTML/RTF masquerading as .docx" do
    expect { generate_from("<html><body>oops</body></html>" * 5) }
      .to raise_error(DocxTemplating::InvalidTemplate, /not a Zip/)
  end

  it "raises for a valid Zip that is not a Word document" do
    io = StringIO.new
    Zip::OutputStream.write_buffer(io) { |z| z.put_next_entry("hello.txt"); z.write("hi") }
    expect { generate_from(io.string) }
      .to raise_error(DocxTemplating::InvalidTemplate, /not a Word document/)
  end

  it "raises InvalidTemplate for a missing path" do
    expect { DocxTemplating::Report.new("/no/such/file.docx") { |r| r.add_field(:x, "y") }.generate }
      .to raise_error(DocxTemplating::InvalidTemplate, /not found/)
  end

  it "still generates from a valid template" do
    doc = document(render(tp("[X]")) { |r| r.add_field(:x, "ok") })
    expect(doc.at_xpath("//w:t", DocxTemplating::NS::DOC).text).to eq("ok")
  end
end
