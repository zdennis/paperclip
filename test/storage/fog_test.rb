require './test/helper'
require 'fog'

Fog.mock!

class FogTest < Test::Unit::TestCase
  def create_fog_shim_vault(options = {})
    default_options = Paperclip::Attachment.default_options.merge(:storage => :fog)
    options = default_options.merge(options)
    rebuild_model(options)
    model = Dummy.new
    model.avatar = File.new(fixture_file('5k.png'), 'rb')
    attachment = model.avatar
    Paperclip::ShimVault.new(attachment, options)
  end

  should "expose the fog_public option" do
    vault = create_fog_shim_vault(:fog_public => false)
    assert ! vault.fog_public
  end

  should "have the proper information loading credentials from a file with credentials provided in a path string" do
    vault = create_fog_shim_vault(
      :styles => { :medium => "300x300>", :thumb => "100x100>" },
      :storage => :fog,
      :url => '/:attachment/:filename',
      :fog_directory => "paperclip",
      :fog_credentials => fixture_file('fog.yml'))

    assert_equal vault.fog_credentials[:provider], 'AWS'
  end

  should "have the proper information loading credentials from a file with credentials provided in a File object" do
    vault = create_fog_shim_vault(
      :styles => { :medium => "300x300>", :thumb => "100x100>" },
      :storage => :fog,
      :url => '/:attachment/:filename',
      :fog_directory => "paperclip",
      :fog_credentials => File.new(fixture_file('fog.yml')))

    assert_equal vault.fog_credentials[:provider], 'AWS'
  end

  context "with default values for path and url" do
    setup do
      rebuild_model :styles => { :medium => "300x300>", :thumb => "100x100>" },
                    :storage => :fog,
                    :url => '/:attachment/:filename',
                    :fog_directory => "paperclip",
                    :fog_credentials => {
                      :provider => 'AWS',
                      :aws_access_key_id => 'AWS_ID',
                      :aws_secret_access_key => 'AWS_SECRET'
                    }
      @dummy = Dummy.new
      @dummy.avatar = File.new(fixture_file('5k.png'), 'rb')
    end
    should "be able to interpolate the path without blowing up" do
      assert_equal File.expand_path(File.join(File.dirname(__FILE__), "../../public/avatars/5k.png")),
                   @dummy.avatar.path
    end

    should "clean up file objects" do
      File.stubs(:exist?).returns(true)
      Paperclip::Tempfile.any_instance.expects(:close).at_least_once()
      Paperclip::Tempfile.any_instance.expects(:unlink).at_least_once()

      @dummy.save!
    end
  end

  context "wtf" do
    setup do
      @fog_directory = 'papercliptests'

      @credentials = {
        :provider               => 'AWS',
        :aws_access_key_id      => 'ID',
        :aws_secret_access_key  => 'SECRET'
      }

      @connection = Fog::Storage.new(@credentials)
      @connection.directories.create(
        :key => @fog_directory
      )

      @options = {
        :fog_directory    => @fog_directory,
        :fog_credentials  => @credentials,
        :fog_host         => nil,
        :fog_file         => {:cache_control => 1234},
        :path             => ":attachment/:basename.:extension",
        :storage          => :fog
      }

      rebuild_model(@options)
    end

    context "when assigned" do
      setup do
        @file = File.new(fixture_file('5k.png'), 'rb')
        @dummy = Dummy.new
        @dummy.avatar = @file
      end

      teardown do
        @file.close
        directory = @connection.directories.new(:key => @fog_directory)
        directory.files.each {|file| file.destroy}
        directory.destroy
      end

      context "without a bucket" do
        setup do
          @connection.directories.get(@fog_directory).destroy
        end

        should "create the bucket" do
          assert @dummy.save
          assert @connection.directories.get(@fog_directory)
        end
      end

      context "with a bucket" do
        should "succeed" do
          assert @dummy.save
        end
      end

      context "without a fog_host" do
        setup do
          rebuild_model(@options.merge(:fog_host => nil))
          @dummy = Dummy.new
          @dummy.avatar = StringIO.new('.')
          @dummy.save
        end

        should "provide a public url" do
          assert !@dummy.avatar.url.nil?
        end
      end

      context "with a fog_host" do
        setup do
          rebuild_model(@options.merge(:fog_host => 'http://example.com'))
          @dummy = Dummy.new
          @dummy.avatar = StringIO.new('.')
          @dummy.save
        end

        should "provide a public url" do
          assert @dummy.avatar.url =~ /^http:\/\/example\.com\/avatars\/stringio\.txt\?\d*$/
        end
      end

      context "with a fog_host that includes a wildcard placeholder" do
        setup do
          rebuild_model(
            :fog_directory    => @fog_directory,
            :fog_credentials  => @credentials,
            :fog_host         => 'http://img%d.example.com',
            :path             => ":attachment/:basename.:extension",
            :storage          => :fog
          )
          @dummy = Dummy.new
          @dummy.avatar = StringIO.new('.')
          @dummy.save
        end

        should "provide a public url" do
          assert @dummy.avatar.url =~ /^http:\/\/img[0123]\.example\.com\/avatars\/stringio\.txt\?\d*$/
        end
      end

      context "with a valid bucket name for a subdomain" do
        should "provide an url in subdomain style" do
          assert_match /^https:\/\/papercliptests.s3.amazonaws.com\/avatars\/5k.png\?\d*$/, @dummy.avatar.url
        end
      end

      context "with an invalid bucket name for a subdomain" do
        setup do
          rebuild_model(@options.merge(:fog_directory => "this_is_invalid"))
          @dummy = Dummy.new
          @dummy.avatar = @file
          @dummy.save
        end

        should "not match the bucket-subdomain restrictions" do
          invalid_subdomains = %w(this_is_invalid in iamareallylongbucketnameiamareallylongbucketnameiamareallylongbu invalid- inval..id inval-.id inval.-id -invalid 192.168.10.2)
          invalid_subdomains.each do |name|
            assert_no_match Paperclip::Storage::Fog::AWS_BUCKET_SUBDOMAIN_RESTRICTON_REGEX, name
          end
        end

        should "provide an url in folder style" do
          assert_match /^https:\/\/s3.amazonaws.com\/this_is_invalid\/avatars\/5k.png\?\d*$/, @dummy.avatar.url
        end

      end

    end
  end
end
