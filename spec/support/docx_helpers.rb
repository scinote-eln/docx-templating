require "zip"
require "stringio"
require "tmpdir"

# Helpers to build a minimal valid .docx template, run a document against it,
# and inspect the resulting package.
module DocxHelpers
  W  = DocxTemplating::NS::W
  R  = DocxTemplating::NS::R
  NS = DocxTemplating::NS::DOC

  # Build a minimal valid .docx whose body is `body_inner`, with all the
  # namespaces inserted fragments may need declared on the document root.
  def build_docx(body_inner)
    document = <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <w:document xmlns:w="#{W}" xmlns:r="#{R}"
        xmlns:wp="#{DocxTemplating::NS::WP}" xmlns:a="#{DocxTemplating::NS::A}" xmlns:pic="#{DocxTemplating::NS::PIC}">
        <w:body>#{body_inner}</w:body>
      </w:document>
    XML

    content_types = <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <Types xmlns="#{DocxTemplating::NS::CT}">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
      </Types>
    XML

    rels = <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <Relationships xmlns="#{DocxTemplating::NS::PR}">
        <Relationship Id="rId1" Type="#{R}/officeDocument" Target="word/document.xml"/>
      </Relationships>
    XML

    io = StringIO.new
    Zip::OutputStream.write_buffer(io) do |z|
      z.put_next_entry("[Content_Types].xml");          z.write(content_types)
      z.put_next_entry("_rels/.rels");                  z.write(rels)
      z.put_next_entry("word/document.xml");            z.write(document)
      z.put_next_entry("word/_rels/document.xml.rels"); z.write(%(<?xml version="1.0"?><Relationships xmlns="#{DocxTemplating::NS::PR}"/>))
    end
    io.string
  end

  # A simple template paragraph.
  def tp(text)
    %(<w:p><w:r><w:t xml:space="preserve">#{text}</w:t></w:r></w:p>)
  end

  # Build a template from `body`, run a document (configured by the block), and
  # return the generated package bytes.
  def render(body, **opts, &block)
    DocxTemplating::Document.new(io: build_docx(body), **opts, &block).generate
  end

  def entries(bytes)
    result = {}
    Zip::File.open_buffer(StringIO.new(bytes)) do |zip|
      zip.each { |e| result[e.name] = e.get_input_stream.read unless e.directory? }
    end
    result
  end

  def document(bytes)
    Nokogiri::XML(entries(bytes)["word/document.xml"])
  end

  # Joined <w:t> text for each body-level <w:p>.
  def paragraph_texts(doc)
    doc.xpath("//w:body/w:p", NS).map do |p|
      p.xpath(".//w:t", NS).map(&:text).join
    end
  end
end
