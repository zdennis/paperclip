require 'spec_helper'
require 'paperclip/url_generator'

describe Paperclip::UrlGenerator do
  it "uses the given interpolator" do
    expected = "the expected result"
    mock_attachment = MockAttachment.new
    mock_interpolator = MockInterpolator.new(result: expected)

    url_generator = Paperclip::UrlGenerator.new(mock_attachment,
                                                interpolator: mock_interpolator)
    result = url_generator.for(:style_name, {})

    result.should == expected
    mock_interpolator.should have_interpolated_attachment(mock_attachment)
    mock_interpolator.should have_interpolated_style_name(:style_name)
  end

  it "uses the default URL when no file is assigned" do
    mock_attachment = MockAttachment.new
    mock_interpolator = MockInterpolator.new
    default_url = "the default url"
    options = { interpolator: mock_interpolator, default_url: default_url }

    url_generator = Paperclip::UrlGenerator.new(mock_attachment, options)
    url_generator.for(:style_name, {})

    mock_interpolator.should have_interpolated_pattern(default_url)
  end

  it "executes the default URL lambda when no file is assigned" do
    mock_attachment = MockAttachment.new
    mock_interpolator = MockInterpolator.new
    default_url = lambda {|attachment| "the #{attachment.class.name} default url" }
    options = { interpolator: mock_interpolator, default_url: default_url }

    url_generator = Paperclip::UrlGenerator.new(mock_attachment, options)
    url_generator.for(:style_name, {})

    mock_interpolator.should have_interpolated_pattern("the MockAttachment default url")
  end

  it "executes the method named by the symbol as the default URL when no file is assigned" do
    mock_model = MockModel.new
    mock_attachment = MockAttachment.new(model: mock_model)
    mock_interpolator = MockInterpolator.new
    default_url = :to_s
    options = { interpolator: mock_interpolator, default_url: default_url }

    url_generator = Paperclip::UrlGenerator.new(mock_attachment, options)
    url_generator.for(:style_name, {})

    mock_interpolator.should have_interpolated_pattern(mock_model.to_s)
  end

  it "URL-escapes spaces if asked to" do
    expected = "the expected result"
    mock_attachment = MockAttachment.new
    mock_interpolator = MockInterpolator.new(result: expected)
    options = { interpolator: mock_interpolator }
    url_generator = Paperclip::UrlGenerator.new(mock_attachment, options)

    result = url_generator.for(:style_name, {escape: true})

    result.should == "the%20expected%20result"
  end

  it "escapes the result of the interpolator using a method on the object, if asked to escape" do
    expected = Class.new do
      def escape
        "the escaped result"
      end
    end.new
    mock_attachment = MockAttachment.new
    mock_interpolator = MockInterpolator.new(result: expected)
    options = { interpolator: mock_interpolator }
    url_generator = Paperclip::UrlGenerator.new(mock_attachment, options)

    result = url_generator.for(:style_name, {escape: true})

    result.should == "the escaped result"
  end

  it "leaves spaces unescaped as asked to" do
    expected = "the expected result"
    mock_attachment = MockAttachment.new
    mock_interpolator = MockInterpolator.new(result: expected)
    options = { interpolator: mock_interpolator }
    url_generator = Paperclip::UrlGenerator.new(mock_attachment, options)

    result = url_generator.for(:style_name, {escape: false})

    result.should == "the expected result"
  end

  it "defaults to leaving spaces unescaped" do
    expected = "the expected result"
    mock_attachment = MockAttachment.new
    mock_interpolator = MockInterpolator.new(result: expected)
    options = { interpolator: mock_interpolator }
    url_generator = Paperclip::UrlGenerator.new(mock_attachment, options)

    result = url_generator.for(:style_name, {})

    result.should == "the expected result"
  end

  it "produces URLs without the updated_at value when the object does not respond to updated_at" do
    expected = "the expected result"
    mock_interpolator = MockInterpolator.new(result: expected)
    mock_attachment = MockAttachment.new(responds_to_updated_at: false)
    options = { interpolator: mock_interpolator }
    url_generator = Paperclip::UrlGenerator.new(mock_attachment, options)

    result = url_generator.for(:style_name, timestamp: true)

    result.should == expected
  end

  it "produces URLs without the updated_at value when the updated_at value is nil" do
    expected = "the expected result"
    mock_interpolator = MockInterpolator.new(result: expected)
    mock_attachment = MockAttachment.new(responds_to_updated_at: true, updated_at: nil)
    options = { interpolator: mock_interpolator }
    url_generator = Paperclip::UrlGenerator.new(mock_attachment, options)

    result = url_generator.for(:style_name, timestamp: true)

    result.should == expected
  end

  it "produces URLs with the updated_at when it exists, separated with a & if a ? follow by = already exists" do
    expected = "the?expected=result"
    updated_at = 1231231234
    mock_interpolator = MockInterpolator.new(result: expected)
    mock_attachment = MockAttachment.new(updated_at: updated_at)
    options = { interpolator: mock_interpolator }
    url_generator = Paperclip::UrlGenerator.new(mock_attachment, options)

    result = url_generator.for(:style_name, timestamp: true)

    result.should == "#{expected}&#{updated_at}"
  end

  it "produces URLs without the updated_at when told to do as much" do
    expected = "the expected result"
    updated_at = 1231231234
    mock_interpolator = MockInterpolator.new(result: expected)
    mock_attachment = MockAttachment.new(updated_at: updated_at)
    options = { interpolator: mock_interpolator }
    url_generator = Paperclip::UrlGenerator.new(mock_attachment, options)

    result = url_generator.for(:style_name, timestamp: false)

    result.should == expected
  end

  it "produces the correct URL when the instance has a file name" do
    expected = "the expected result"
    mock_attachment = MockAttachment.new(original_filename: 'exists')
    mock_interpolator = MockInterpolator.new
    options = { interpolator: mock_interpolator, url: expected}

    url_generator = Paperclip::UrlGenerator.new(mock_attachment, options)
    url_generator.for(:style_name, {})

    mock_interpolator.should have_interpolated_pattern(expected)
  end
end
