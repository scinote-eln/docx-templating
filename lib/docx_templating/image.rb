module DocxTemplating
  # Inserts an image at a text placeholder. Registers the binary, a relationship
  # and a content-type with the Template, then drops an inline <w:drawing>.
  class Image < Field
    EMU_PER_CM = 360_000

    CONTENT_TYPES = {
      "png" => "image/png", "jpg" => "image/jpeg", "jpeg" => "image/jpeg",
      "gif" => "image/gif", "bmp" => "image/bmp"
    }.freeze

    def initialize(opts, &block)
      @width_cm  = opts[:width]  || 4.0
      @height_cm = opts[:height] || 3.0
      super
    end

    def replace!(doc, template)
      path = @data_source.value
      return unless path && template

      para = doc.xpath(".//w:p", NS::DOC).find do |p|
        p.xpath(".//w:t", NS::DOC).map(&:text).join.include?(to_placeholder)
      end
      return unless para

      basename = File.basename(path)
      ext = File.extname(basename).sub(".", "").downcase
      rid = template.add_image(basename, IO.binread(path), CONTENT_TYPES.fetch(ext, "application/octet-stream"))

      para.children = drawing(rid)
    end

    private

    def drawing(rid)
      cx = (@width_cm * EMU_PER_CM).to_i
      cy = (@height_cm * EMU_PER_CM).to_i
      %(<w:r><w:drawing>) +
        %(<wp:inline xmlns:wp="#{NS::WP}" xmlns:a="#{NS::A}" xmlns:pic="#{NS::PIC}" xmlns:r="#{NS::R}" distT="0" distB="0" distL="0" distR="0">) +
        %(<wp:extent cx="#{cx}" cy="#{cy}"/>) +
        %(<wp:docPr id="1" name="Picture"/>) +
        %(<a:graphic><a:graphicData uri="#{NS::PIC}">) +
        %(<pic:pic><pic:nvPicPr><pic:cNvPr id="0" name="#{Wml.escape(File.basename(@data_source.value))}"/><pic:cNvPicPr/></pic:nvPicPr>) +
        %(<pic:blipFill><a:blip r:embed="#{rid}"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>) +
        %(<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="#{cx}" cy="#{cy}"/></a:xfrm>) +
        %(<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic>) +
        %(</a:graphicData></a:graphic></wp:inline></w:drawing></w:r>)
    end
  end
end
