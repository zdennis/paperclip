# encoding: utf-8
require './test/helper'

class UrlGeneratorTest < Test::Unit::TestCase
  should "use the given interpolator"
  should "use the default URL when  no file is assigned"
  should "execute the default URL lambda when no file is assigned"
  should "execute the method named by the symbol as the default URL when no file is assigned"
  should "execute the :url option"
  should "URL-escape spaces"
  should "produce URLs without the updated_at value when the object does not respond to updated_at"
  should "produce URLs without the updated_at value when the updated_at value is nil"
  should "produce URLs with the updated_at when it exists"
  should "produce URLs without the updated_at when told to do as much" # deprecated? @attachment.url(:style, false)
  context "an instance with an id" do
    should "produce the correct URL"
    should "produce the URL when the file does not exist"
  end



  context "setting an interpolation class" do
    should "produce the URL with the given interpolations" do
      Interpolator = Class.new do
        def self.interpolate(pattern, attachment, style_name)
          "hello"
        end
      end

      instance = Dummy.new
      url_generator = UrlGenerator.new(mock_attachment, :interpolator => Interpolator)

      assert_equal "hello", attachment.for(:ignored, {})
    end
  end

  should "return the url by interpolating the default_url option when no file assigned" do
    attachment = attachment(:default_url => ":class/blegga.png")
    model = attachment.instance
    assert_nil model.avatar_file_name
    url_generator = UrlGenerator.new(attachment, :interpolator => Interpolator)

    assert_equal "fake_models/blegga.png", url_generator.for(:ignored, {})
  end

  should "return the url by executing and interpolating the default_url Proc when no file assigned" do
    attachment = attachment(:default_url => lambda { |a| ":class/blegga.png" })
    model = attachment.instance
    assert_nil model.avatar_file_name
    url_generator = UrlGenerator.new(attachment, :interpolator => Interpolator)

    assert_equal "fake_models/blegga.png", url_generator.for(:ignored, {})
  end

  should "return the url by executing and interpolating the default_url Proc with attachment arg when no file assigned" do
    @attachment = attachment :default_url => lambda { |a| a.instance.some_method_to_determine_default_url }
    @model = @attachment.instance
    @model.stubs(:some_method_to_determine_default_url).returns(":class/blegga.png")
    assert_nil @model.avatar_file_name
    assert_equal "fake_models/blegga.png", @attachment.url
  end

  should "return the url by executing and interpolating the default_url when assigned with symbol as method in attachment model" do
    @attachment = attachment :default_url => :some_method_to_determine_default_url
    @model = @attachment.instance
    @model.stubs(:some_method_to_determine_default_url).returns(":class/female_:style_blegga.png")
    assert_equal "fake_models/female_foostyle_blegga.png", @attachment.url(:foostyle)
  end

    context "with a file that has space in file name" do
      setup do
        @attachment.stubs(:instance_read).with(:file_name).returns("spaced file.png")
        @attachment.stubs(:instance_read).with(:content_type).returns("image/png")
        @attachment.stubs(:instance_read).with(:file_size).returns(12345)
        dtnow = DateTime.now
        @now = Time.now
        Time.stubs(:now).returns(@now)
        @attachment.stubs(:instance_read).with(:updated_at).returns(dtnow)
      end

      should "returns an escaped version of the URL" do
        assert_match /\/spaced%20file\.png/, @attachment.url
      end
    end

      context "with the updated_at field removed" do
        setup do
          @attachment.stubs(:instance_read).with(:updated_at).returns(nil)
        end

        should "only return the url without the updated_at when sent #url" do
          assert_match "/avatars/#{@instance.id}/blah/5k.png", @attachment.url(:blah)
        end
      end

          context "and saved" do
            setup do
              @attachment.save
            end

            should "return the real url" do
              file = @attachment.to_file
              assert file
              assert_match %r{^/system/avatars/#{@instance.id}/original/5k\.png}, @attachment.url
              assert_match %r{^/system/avatars/#{@instance.id}/small/5k\.jpg}, @attachment.url(:small)
              file.close
            end
          end
    context "with a file assigned in the database" do
      setup do
        @attachment.stubs(:instance_read).with(:file_name).returns("5k.png")
        @attachment.stubs(:instance_read).with(:content_type).returns("image/png")
        @attachment.stubs(:instance_read).with(:file_size).returns(12345)
        dtnow = DateTime.now
        @now = Time.now
        Time.stubs(:now).returns(@now)
        @attachment.stubs(:instance_read).with(:updated_at).returns(dtnow)
      end

      should "return a correct url even if the file does not exist" do
        assert_nil @attachment.to_file
        assert_match %r{^/system/avatars/#{@instance.id}/blah/5k\.png}, @attachment.url(:blah)
      end

      should "make sure the updated_at mtime is in the url if it is defined" do
        assert_match %r{#{@now.to_i}$}, @attachment.url(:blah)
      end

      should "make sure the updated_at mtime is NOT in the url if false is passed to the url method" do
        assert_no_match %r{#{@now.to_i}$}, @attachment.url(:blah, false)
      end
    end

  context "An attachment with :url that is a proc" do
    setup do
      rebuild_model :url => lambda{ |attachment| "path/#{attachment.instance.other}.:extension" }

      @file = File.new(File.join(File.dirname(__FILE__),
                                 "fixtures",
                                 "5k.png"), 'rb')
      @dummyA = Dummy.new(:other => 'a')
      @dummyA.avatar = @file
      @dummyB = Dummy.new(:other => 'b')
      @dummyB.avatar = @file
    end

    teardown { @file.close }

    should "return correct url" do
      assert_equal "path/a.png", @dummyA.avatar.url(:original, false)
      assert_equal "path/b.png", @dummyB.avatar.url(:original, false)
    end
  end


  # I re-write these tests as should "..." statements above, but left off here:
  context "An attachment" do
    setup do
      @file = StringIO.new("...")
    end
    context "using default time zone" do
      setup do
        rebuild_model :url => "X"
        @dummy = Dummy.new
        @dummy.avatar = @file
      end

      should "generate a url with a timestamp when passing true" do
        assert_equal "X?#{@dummy.avatar_updated_at.to_i.to_s}", @dummy.avatar.url(:style, true)
      end

      should "not generate a url with a timestamp when passing false" do
        assert_equal "X", @dummy.avatar.url(:style, false)
      end

      should "generate a url with a timestamp when setting a timestamp option" do
        assert_equal "X?#{@dummy.avatar_updated_at.to_i.to_s}", @dummy.avatar.url(:style, :timestamp => true)
      end

      should "not generate a url with a timestamp when setting a timestamp option to false" do
        assert_equal "X", @dummy.avatar.url(:style, :timestamp => false)
      end
    end
  end

  context "An attachment" do
    setup do
      @old_defaults = Paperclip::Attachment.default_options.dup
      Paperclip::Attachment.default_options.merge!({
        :path => ":rails_root/tmp/:attachment/:class/:style/:id/:basename.:extension"
      })
      FileUtils.rm_rf("tmp")
      rebuild_model
      @instance = Dummy.new
      @instance.stubs(:id).returns 123
      @attachment = Paperclip::Attachment.new(:avatar, @instance)
      @file = File.new(File.join(File.dirname(__FILE__), "fixtures", "5k.png"), 'rb')
    end

    teardown do
      @file.close
      Paperclip::Attachment.default_options.merge!(@old_defaults)
    end

    should "return its default_url when no file assigned" do
      assert @attachment.to_file.nil?
      assert_equal "/avatars/original/missing.png", @attachment.url
      assert_equal "/avatars/blah/missing.png", @attachment.url(:blah)
    end
  end
end
