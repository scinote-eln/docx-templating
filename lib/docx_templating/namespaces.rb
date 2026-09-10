module DocxTemplating
  # WordprocessingML / OPC namespaces used throughout.
  module NS
    W  = "http://schemas.openxmlformats.org/wordprocessingml/2006/main".freeze
    R  = "http://schemas.openxmlformats.org/officeDocument/2006/relationships".freeze
    CT = "http://schemas.openxmlformats.org/package/2006/content-types".freeze
    PR = "http://schemas.openxmlformats.org/package/2006/relationships".freeze
    WP = "http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing".freeze
    A  = "http://schemas.openxmlformats.org/drawingml/2006/main".freeze
    PIC = "http://schemas.openxmlformats.org/drawingml/2006/picture".freeze

    # For Nokogiri xpath lookups against document.xml
    DOC = { "w" => W, "r" => R }.freeze
  end
end
