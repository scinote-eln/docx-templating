# docx-templating

Generate Microsoft Word `.docx` documents by filling a `.docx` template with dynamic content — plain fields, HTML-formatted text, lists, repeating table rows, checklists, and images.

## Install

```ruby
gem "docx-templating"
```

## Quick example

Author a `.docx` template in Word with `[PLACEHOLDERS]`, then fill them:

```ruby
require "docx-templating"

document = DocxTemplating::Document.new("template.docx") do |r|
  r.add_field :company_name, "Acme Corp"
  r.add_field :date, Date.today.to_s

  r.add_text :summary, "<p>Quarterly results were <strong>strong</strong>.</p><ul><li>Revenue up</li><li>Costs down</li></ul>"

  r.add_table :items, @line_items do |t|
    t.add_column :product
    t.add_column :price
  end

  r.add_checklist :tasks, [
    { text: "Design approved", checked: true },
    { text: "Code reviewed",   checked: false }
  ]

  r.add_image :logo, "logo.png", width: 4, height: 2   # cm
end

document.generate("out.docx")
```

## What it fills

- **Fields** — `add_field(name, value)` replaces `[NAME]` with plain text. Placeholders that Word split across runs are handled by merging runs per paragraph.
- **Texts** — `add_text(name, html)` replaces a placeholder paragraph with HTML-derived content: paragraphs, headings (`h1`–`h6` → Word `HeadingN` styles), inline `strong`/`b`, `em`/`i`, `u`, `br`, and `ul`/`ol` lists (including nested). Unknown/foreign tags are unwrapped (text kept) and HTML entities are decoded, so only valid WordprocessingML is produced, and HTML `<table>` (with `th`/`thead` headers, `colspan`, and alignment) into native Word tables.
- **Tables** — `add_table(name, collection) { |t| t.add_column(:field) }` repeats the template row that contains the column placeholders, once per record.
- **Tables from data** — `add_table_from_data(name, data)` builds a whole table at a placeholder from structured/JSON data (`contents` 2D array, optional `columns_title`, `rows_title`, and per-cell `cells_attributes` styles). No template row needed; when the placeholder sits inside text the paragraph is split around the inserted table.
- **Checklists** — `add_checklist(name, items)` renders one paragraph per item prefixed with ☑ / ☐. Items may be `{text:, checked:}` hashes, `[text, checked]` arrays, objects responding to `#text`/`#checked`, or bare strings.
- **Images** — `add_image(name, path, width:, height:)` embeds the file under `word/media/`, registers the relationship and content type, and inserts an inline drawing at the placeholder. Sizes are in centimetres.
- **Inline images** — `add_inline_image(name, path, width:, height:, dpi:)` places an image inline at a text placeholder while keeping the surrounding text (the placeholder can appear mid-sentence, or more than once). Sizes accept pixels (`200`, `"200px"`, converted via `dpi:`, default 96) or explicit units (`"4cm"`, `"50mm"`, `"2in"`, `"12pt"`).

## Configurable delimiters

```ruby
DocxTemplating.delimiters = :curly                       # {{NAME}} globally
DocxTemplating::Document.new("t.docx", delimiters: :curly) # or per document
```

Presets `:square` (default) and `:curly`, or a custom `["<<", ">>"]`-style pair.

## Status & limitations

This is an initial implementation focused on the common document-generation needs:

- HTML lists are rendered with bullet/number **prefixes**, not native Word numbering (`numbering.xml`). This keeps the output self-contained; native list styles are a planned enhancement.
- Hyperlinks are unwrapped to their visible text (the `href` is dropped).
- Sections and nested tables are not yet implemented.
- Field substitution merges runs within a paragraph that contains a placeholder, so mixed inline formatting inside such a paragraph is consolidated.

## Development

Run the test suite (RSpec):

```bash
bundle install
bundle exec rspec
```

Or in Docker, without a local Ruby:

```bash
docker build -t docx-templating-test .
docker run --rm docx-templating-test
```

## License

MIT.
