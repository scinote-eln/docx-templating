require_relative "lib/docx_templating/version"

Gem::Specification.new do |spec|
  spec.name        = "docx-templating"
  spec.version     = DocxTemplating::VERSION
  spec.authors     = ["Your Name"]
  spec.summary     = "Generate .docx documents from templates: fields, HTML text, lists, tables, checklists, images."
  spec.description  = "A template-based Word (.docx) document generator inspired by odf-report. " \
                      "Fill placeholders in a .docx template with plain values, HTML-formatted text " \
                      "(paragraphs, headings, inline styles, ul/ol lists), repeating table rows, " \
                      "checklists and images — handling Word's split-run placeholders."
  spec.homepage    = "https://github.com/scinote-eln//docx-templating"
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.4"

  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE.txt"]
  spec.require_paths = ["lib"]

  spec.add_dependency "nokogiri", ">= 1.12"
  spec.add_dependency "rubyzip", ">= 2.0", "< 3.0" # 3.x writes zip64 headers some consumers reject

  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rubocop"
end
