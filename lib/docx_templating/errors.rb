module DocxTemplating
  # Base error for the library.
  class Error < StandardError; end

  # Raised when the template is not a readable .docx (not a Zip/OOXML file,
  # empty, truncated, or missing word/document.xml).
  class InvalidTemplate < Error; end
end
