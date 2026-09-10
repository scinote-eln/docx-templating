require "zip"
require "nokogiri"

module DocxTemplating
  # Reads a .docx (an OPC zip), mutates word/document.xml, and
  # writes a new .docx — injecting any image media, relationships and content
  # types that were registered during processing.
  class Template
    DOCUMENT      = "word/document.xml".freeze
    DOC_RELS      = "word/_rels/document.xml.rels".freeze
    CONTENT_TYPES = "[Content_Types].xml".freeze

    def initialize(path = nil, io: nil)
      @path = path
      @io = io
      @media = {}            # "word/media/x.png" => binary
      @rels = []             # { id:, type:, target: }
      @content_types = {}    # extension => mime-type
    end

    # Register an image part; returns the relationship id to reference.
    def add_image(basename, binary, content_type)
      ext = File.extname(basename).sub(".", "").downcase
      name = "word/media/#{basename}"
      @media[name] = binary
      @content_types[ext] = content_type
      rid = "rIdImg#{@rels.size + 1}"
      @rels << { id: rid, type: "#{NS::R}/image", target: "media/#{basename}" }
      rid
    end

    # Process the document: yields the parsed document.xml for mutation, then
    # writes the resulting package. Order-independent: all parts are buffered,
    # document.xml is processed first (which is what registers media/rels/types),
    # and only then are the rels and content-types parts injected.
    def update(&mutator)
      validate_source!

      parts = {}
      order = []
      with_zip do |zip|
        zip.each do |entry|
          next if entry.directory?
          order << entry.name
          parts[entry.name] = entry.get_input_stream.read
        end
      end

      unless parts.key?(DOCUMENT)
        raise InvalidTemplate, "#{source_label} is a Zip but not a Word document (missing #{DOCUMENT})"
      end

      doc = Nokogiri::XML(parts[DOCUMENT])
      mutator.call(doc)
      parts[DOCUMENT] = serialize(doc)

      if parts[DOC_RELS]
        parts[DOC_RELS] = inject_rels(parts[DOC_RELS])
      elsif !@rels.empty?
        parts[DOC_RELS] = new_rels_part
        order << DOC_RELS
      end

      parts[CONTENT_TYPES] = inject_content_types(parts[CONTENT_TYPES]) if parts[CONTENT_TYPES]

      @media.each do |name, binary|
        next if parts.key?(name)
        parts[name] = binary
        order << name
      end

      io = Zip::OutputStream.write_buffer do |out|
        order.each do |name|
          out.put_next_entry(name)
          out.write(parts[name])
        end
      end
      io.string
    end

    private

    def with_zip(&block)
      if @io
        Zip::File.open_buffer(@io, &block)
      else
        Zip::File.open(@path, &block)
      end
    end

    ZIP_SIGNATURES = ["PK\x03\x04", "PK\x05\x06", "PK\x07\x08"].map(&:b).freeze
    EOCD_MIN_SIZE  = 22

    # Fail fast with a clear message when the source is not a valid .docx,
    # instead of surfacing a cryptic rubyzip "end of central directory" error.
    def validate_source!
      head, size =
        if @io
          data = @io.is_a?(String) ? @io : peek_io
          [data.byteslice(0, 4), data.bytesize]
        else
          raise InvalidTemplate, "template file not found: #{@path.inspect}" unless @path && File.file?(@path)
          [File.binread(@path, 4), File.size(@path)]
        end

      if size.to_i < EOCD_MIN_SIZE
        raise InvalidTemplate, "#{source_label} is empty or truncated (#{size.to_i} bytes) \u2014 a .docx must be a valid Zip/OOXML file"
      end

      unless ZIP_SIGNATURES.include?(head)
        hex = head.to_s.bytes.map { |b| format("%02x", b) }.join(" ")
        raise InvalidTemplate,
              "#{source_label} is not a Zip/OOXML (.docx) file (starts with bytes: #{hex}). " \
              "It may be a legacy .doc, RTF, HTML, or a corrupt/truncated upload."
      end
    end

    def peek_io
      pos = (@io.pos rescue 0)
      data = @io.read
      (@io.rewind rescue @io.seek(pos))
      data.to_s
    end

    def source_label
      @path ? "template #{@path}" : "the provided template data"
    end

    def serialize(doc)
      doc.to_xml(indent: 0, save_with: Nokogiri::XML::Node::SaveOptions::AS_XML)
    end

    def inject_rels(xml)
      return xml if @rels.empty?
      doc = Nokogiri::XML(xml)
      root = doc.at_xpath("/*")
      @rels.each do |r|
        node = doc.create_element("Relationship", "Id" => r[:id], "Type" => r[:type], "Target" => r[:target])
        root << node
      end
      serialize(doc)
    end

    def inject_content_types(xml)
      return xml if @content_types.empty?
      doc = Nokogiri::XML(xml)
      root = doc.at_xpath("/*")
      existing = doc.xpath("/*/*[local-name()='Default']").map { |d| d["Extension"] }
      @content_types.each do |ext, type|
        next if existing.include?(ext)
        root << doc.create_element("Default", "Extension" => ext, "ContentType" => type)
      end
      serialize(doc)
    end

    # If parts we needed to extend did not exist in the template, create them.
    def new_rels_part
      rels = @rels.map { |r| %(<Relationship Id="#{r[:id]}" Type="#{r[:type]}" Target="#{r[:target]}"/>) }.join
      %(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>) +
        %(<Relationships xmlns="#{NS::PR}">#{rels}</Relationships>)
    end
  end
end
