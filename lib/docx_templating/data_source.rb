module DocxTemplating
  # Resolves a field's value from a literal or from a record (Hash / object).
  class DataSource
    def initialize(opts, &block)
      @field = opts[:value] || opts[:name]
      @literal = !opts[:value].nil? && !opts[:value].is_a?(Symbol)
      @block = block
      @record = nil
    end

    def set_source(record)
      @record = record
      self
    end

    def value
      return @block.call(@record) if @block
      return @field if @literal || @record.nil?

      extract(@record, @field)
    end

    private

    def extract(record, field)
      if record.is_a?(Hash)
        record[field] || record[field.to_s] || record[field.to_sym]
      elsif record.respond_to?(field)
        record.public_send(field)
      end
    end
  end
end
