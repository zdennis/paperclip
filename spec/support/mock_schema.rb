require 'paperclip/schema'

class MockSchema
  include Paperclip::Schema

  def initialize(table_name = nil)
    @table_name = table_name
    @columns = {}
    @deleted_columns = []
  end

  def column(name, type)
    @columns[name] = type
  end

  def remove_column(table_name, column_name)
    if @table_name.nil? || @table_name == table_name
      @columns.delete(column_name)
      @deleted_columns.push(column_name)
    end
  end

  def has_column?(column_name)
    @columns.key?(column_name)
  end

  def has_deleted_column?(column_name)
    @deleted_columns.include?(column_name)
  end

  def type_of(column_name)
    @columns[column_name]
  end
end
