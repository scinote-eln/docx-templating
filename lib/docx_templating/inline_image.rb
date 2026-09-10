module DocxTemplating
  # Inserts an image at a *text* placeholder, inline with the surrounding text,
  # without needing a pre-placed image in the template. Mirrors the odf-report
  # inline-image API.
  #
  #   report.add_inline_image(:photo, "/path/to/photo.png", width: "4cm", height: "3cm")
  #   report.add_inline_image(:photo, "/path/to/photo.png", width: 200, height: 150)   # pixels
  #   report.add_inline_image(:photo, "/path/to/photo.png", width: "200px", dpi: 72)
  #
  # In the template, just type the placeholder where the image should appear:
  #   Employee photo: [PHOTO]
  #
  # width/height accept a Numeric or "200px"/"200" (pixels, converted via :dpi,
  # default 96) or an explicit unit string ("4cm", "50mm", "2in", "12pt", "1pc").
  # Unlike a Word table, a drawing can live in a run, so the image is placed
  # inline and the surrounding text in the paragraph is preserved.
  class InlineImage < Image
    EMU_PER_INCH = 914_400
    DEFAULT_DPI  = 96
    DEFAULT_SIZE = "3cm".freeze

    UNITS_EMU = { "cm" => 360_000, "mm" => 36_000, "in" => 914_400, "pt" => 12_700, "pc" => 152_400 }.freeze
    UNIT_RE   = /\A\s*([\d.]+)\s*(cm|mm|in|pt|pc)\s*\z/i
    PX_RE     = /\A\s*([\d.]+)\s*(?:px)?\s*\z/i

    def initialize(opts, &block)
      @dpi = (opts[:dpi] || DEFAULT_DPI).to_f
      @cx  = to_emu(opts[:width]  || DEFAULT_SIZE)
      @cy  = to_emu(opts[:height] || DEFAULT_SIZE)
      super
    end

    def replace!(doc, template)
      path = @data_source.value
      return unless path && template

      paragraphs = doc.xpath(".//w:p", NS::DOC).select do |p|
        p.xpath(".//w:t", NS::DOC).map(&:text).join.include?(to_placeholder)
      end
      return if paragraphs.empty?

      ext = File.extname(path).sub(".", "").downcase
      rid = template.add_image(File.basename(path), IO.binread(path),
                               CONTENT_TYPES.fetch(ext, "application/octet-stream"))

      paragraphs.each { |para| insert_inline(para, rid) }
    end

    private

    # Rebuild the paragraph's runs as: text before, the image run, text after
    # (for each placeholder occurrence). Preserves the paragraph properties.
    def insert_inline(para, rid)
      joined   = para.xpath(".//w:t", NS::DOC).map(&:text).join
      segments = joined.split(to_placeholder, -1)

      pieces = []
      segments.each_with_index do |seg, i|
        pieces << Wml.run(seg) unless seg.empty?
        pieces << image_run(rid) if i < segments.size - 1
      end

      ppr = para.at_xpath("./w:pPr", NS::DOC)
      para.children = "#{ppr&.to_xml}#{pieces.join}"
    end

    def to_emu(value)
      return nil if value.nil?
      return px_to_emu(value) if value.is_a?(Numeric)

      case value.to_s
      when UNIT_RE then (Float($1) * UNITS_EMU[$2.downcase]).round
      when PX_RE   then px_to_emu(Float($1))
      else to_emu(DEFAULT_SIZE)
      end
    end

    def px_to_emu(pixels)
      (pixels.to_f / @dpi * EMU_PER_INCH).round
    end

    def image_run(rid)
      %(<w:r><w:drawing>) +
        %(<wp:inline xmlns:wp="#{NS::WP}" xmlns:a="#{NS::A}" xmlns:pic="#{NS::PIC}" xmlns:r="#{NS::R}" distT="0" distB="0" distL="0" distR="0">) +
        %(<wp:extent cx="#{@cx}" cy="#{@cy}"/>) +
        %(<wp:docPr id="1" name="Picture"/>) +
        %(<a:graphic><a:graphicData uri="#{NS::PIC}">) +
        %(<pic:pic><pic:nvPicPr><pic:cNvPr id="0" name="#{Wml.escape(File.basename(@data_source.value))}"/><pic:cNvPicPr/></pic:nvPicPr>) +
        %(<pic:blipFill><a:blip r:embed="#{rid}"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>) +
        %(<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="#{@cx}" cy="#{@cy}"/></a:xfrm>) +
        %(<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic>) +
        %(</a:graphicData></a:graphic></wp:inline></w:drawing></w:r>)
    end
  end
end
