# Run the test suite in a clean container:
#   docker build -t docx-templating-test .
#   docker run --rm docx-templating-test
#
FROM ruby:3.4

WORKDIR /app

# Dependency layer — cached unless the gemspec / Gemfile / version change.
COPY Gemfile docx-templating.gemspec ./
COPY lib/docx_templating/version.rb lib/docx_templating/version.rb
RUN bundle install

# Application code and specs.
COPY . .

CMD ["bundle", "exec", "rspec"]
