require 'spec_helper'
require 'paperclip/schema'

describe Paperclip::Schema, 'migrating up' do
  subject do
    MockSchema.new.tap do |mock_schema|
      mock_schema.has_attached_file(:avatar)
    end
  end

  it { should have_column(:avatar_file_name) }
  it { should have_column(:avatar_content_type) }
  it { should have_column(:avatar_file_size) }
  it { should have_column(:avatar_updated_at) }

  it 'makes the file_name column a string' do
    subject.type_of(:avatar_file_name).should == :string
  end

  it 'makes the content_type column a string' do
    subject.type_of(:avatar_content_type).should == :string
  end

  it 'makes the file_size column an integer' do
    subject.type_of(:avatar_file_size).should == :integer
  end

  it 'makes the updated_at column a datetime' do
    subject.type_of(:avatar_updated_at).should == :datetime
  end
end

describe Paperclip::Schema, 'migrating down' do
  subject do
    MockSchema.new(:users).tap do |mock_schema|
      mock_schema.drop_attached_file(:users, :avatar)
    end
  end

  it { should have_deleted_column(:avatar_file_name) }
  it { should have_deleted_column(:avatar_content_type) }
  it { should have_deleted_column(:avatar_file_size) }
  it { should have_deleted_column(:avatar_updated_at) }
end
