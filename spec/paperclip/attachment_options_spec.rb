require 'spec_helper'
require 'paperclip/attachment_options'

describe Paperclip::AttachmentOptions, 'as a concept' do
  subject { Paperclip::AttachmentOptions.new({}) }

  it { should be_kind_of(Hash) }
  it { should respond_to(:[]) }
  it { should respond_to(:[]=) }
end

describe Paperclip::AttachmentOptions do
  it "remembers options set with []=" do
    attachment_options = Paperclip::AttachmentOptions.new({})
    attachment_options[:foo] = "bar"
    attachment_options[:foo].should == "bar"
  end

  it "delivers the specified options through []" do
    intended_options = {specific_key: "specific value"}
    attachment_options = Paperclip::AttachmentOptions.new(intended_options)
    attachment_options[:specific_key].should == "specific value"
  end
end
