require './test/helper'
require 'aws'

class S3Test < Test::Unit::TestCase
  def rails_env(env)
    silence_warnings do
      Object.const_set(:Rails, stub('Rails', :env => env))
    end
  end

  def setup
    AWS.config(:access_key_id => "TESTKEY", :secret_access_key => "TESTSECRET", :stub_requests => true)
  end

  def teardown
    AWS.config(:access_key_id => nil, :secret_access_key => nil, :stub_requests => nil)
  end

  def create_s3_shim_vault(options = {})
    default_options = Paperclip::Attachment.default_options.merge(:storage => :s3)
    options = default_options.merge(options)
    rebuild_model(options)
    model = Dummy.new
    model.avatar = File.new(fixture_file('5k.png'), 'rb')
    attachment = model.avatar
    Paperclip::ShimVault.new(attachment, options)
  end

  context "Parsing S3 credentials" do
    setup do
      @proxy_settings = {:host => "127.0.0.1", :port => 8888, :user => "foo", :password => "bar"}
      @vault = create_s3_shim_vault(
        :storage => :s3,
        :bucket => "testing",
        :http_proxy => @proxy_settings,
        :s3_credentials => {:not => :important})
    end

    should "get the correct credentials when RAILS_ENV is production" do
      rails_env("production")
      assert_equal({:key => "12345"},
                   @vault.parse_credentials('production' => {:key => '12345'},
                                             :development => {:key => "54321"}))
    end

    should "get the correct credentials when RAILS_ENV is development" do
      rails_env("development")
      assert_equal({:key => "54321"},
                   @vault.parse_credentials('production' => {:key => '12345'},
                                             :development => {:key => "54321"}))
    end

    should "return the argument if the key does not exist" do
      rails_env("not really an env")
      assert_equal({:test => "12345"}, @vault.parse_credentials(:test => "12345"))
    end

    should "support HTTP proxy settings" do
      rails_env("development")
      assert_equal(true, @vault.using_http_proxy?)
      assert_equal(@proxy_settings[:host], @vault.http_proxy_host)
      assert_equal(@proxy_settings[:port], @vault.http_proxy_port)
      assert_equal(@proxy_settings[:user], @vault.http_proxy_user)
      assert_equal(@proxy_settings[:password], @vault.http_proxy_password)
    end
  end

  should "populate the bucket_name via s3_credentials" do
    vault = create_s3_shim_vault(:s3_credentials => {:bucket => 'testing'})
    assert_equal vault.bucket_name, 'testing'
  end

  should "populate the bucket_name via bucket option" do
    vault = create_s3_shim_vault(:s3_credentials => {}, :bucket => 'testing')
    assert_equal vault.bucket_name, 'testing'
  end

  context "missing :bucket option" do

    setup do
      rebuild_model :storage => :s3,
                    #:bucket => "testing", # intentionally left out
                    :http_proxy => @proxy_settings,
                    :s3_credentials => {:not => :important}

      @dummy = Dummy.new
      @dummy.avatar = StringIO.new(".")

    end

    should "raise an argument error" do
      exception = assert_raise(ArgumentError) { @dummy.save }
      assert_match /missing required :bucket option/, exception.message
    end

  end

  context "with a specified bucket" do
    setup do
      @vault = create_s3_shim_vault(
        :storage => :s3,
        :s3_credentials => {},
        :bucket => "bucket",
        :path => ":attachment/:basename.:extension",
        :url => ":s3_path_url")
    end

    should "return a url based on an S3 path" do
      attachment = @vault.instance_variable_get('@attachment')
      assert_match %r{^http://s3.amazonaws.com/bucket/avatars/5k.png},
        attachment.url
    end

    should "use the correct bucket" do
      assert_equal "bucket", @vault.s3_bucket.name
    end

    should "use the correct key" do
      assert_equal "avatars/5k.png", @vault.s3_object.key
    end
  end

  context "An attachment that uses S3 for storage and has the style in the path" do
    setup do
      @vault = create_s3_shim_vault(
        :storage => :s3,
        :bucket => "testing",
        :path => ":attachment/:style/:basename.:extension",
        :styles => {
           :thumb => "80x80>"
        },
        :s3_credentials => {
          'access_key_id' => "12345",
          'secret_access_key' => "54321"
        })
    end

    should "use an S3 object based on the correct path for the default style" do
      assert_equal("avatars/original/5k.png", @vault.s3_object.key)
    end

    should "use an S3 object based on the correct path for the custom style" do
      assert_equal("avatars/thumb/5k.png", @vault.s3_object(:thumb).key)
    end
  end

  context "s3_host_name" do
    setup do
      @vault = create_s3_shim_vault(
        :storage => :s3,
        :s3_credentials => {},
        :bucket => "bucket",
        :path => ":attachment/:basename.:extension",
        :s3_host_name => "s3-ap-northeast-1.amazonaws.com"
      )
      @attachment = @vault.instance_variable_get('@attachment')
    end

    should "return a url based on an :s3_host_name path" do
      assert_match %r{^http://s3-ap-northeast-1.amazonaws.com/bucket/avatars/5k.png},
        @attachment.url
    end

    should "use the S3 bucket with the correct host name" do
      assert_equal "s3-ap-northeast-1.amazonaws.com", @vault.s3_bucket.config.s3_endpoint
    end
  end

  context "An attachment that uses S3 for storage and has styles that return different file types" do
    setup do
      @vault = create_s3_shim_vault(
        :styles  => { :large => ['500x500#', :jpg] },
        :storage => :s3,
        :bucket  => "bucket",
        :path => ":attachment/:basename.:extension",
        :s3_credentials => {
          'access_key_id' => "12345",
          'secret_access_key' => "54321"
        })
    end

    should 'use the correct key for the original file mime type' do
      assert_match /.+\/5k.png/, @vault.s3_object.key
    end

    should "use the correct key for the processed file mime type" do
      assert_match /.+\/5k.jpg/, @vault.s3_object(:large).key
    end
  end

  context "An attachment that uses S3 for storage and has spaces in file name" do
    setup do
      rebuild_model :styles  => { :large => ['500x500#', :jpg] },
                    :storage => :s3,
                    :bucket  => "bucket",
                    :s3_credentials => {
                      'access_key_id' => "12345",
                      'secret_access_key' => "54321"
                    }

      @dummy = Dummy.new
      @dummy.avatar = File.new(fixture_file('spaced file.png'), 'rb')
    end

    should "return an unescaped version for path" do
      assert_match /.+\/spaced file\.png/, @dummy.avatar.path
    end

    should "return an escaped version for url" do
      assert_match /.+\/spaced%20file\.png/, @dummy.avatar.url
    end
  end

  should "return a url based on an S3 subdomain" do
    vault = create_s3_shim_vault(
      :storage => :s3,
      :s3_credentials => {},
      :bucket => "bucket",
      :path => ":attachment/:basename.:extension",
      :url => ":s3_domain_url")

    assert_match %r{^http://bucket.s3.amazonaws.com/avatars/5k.png},
      vault.url
  end

  should "produce a URL based on the host alias" do
    vault = create_s3_shim_vault(
      :storage => :s3,
      :s3_credentials => {
        :production   => { :bucket => "prod_bucket" },
        :development  => { :bucket => "dev_bucket" }
      },
      :s3_host_alias => "something.something.com",
      :path => ":attachment/:basename.:extension",
      :url => ":s3_alias_url")
    attachment = vault.instance_variable_get('@attachment')

    assert_match %r{^http://something.something.com/avatars/5k.png},
      attachment.url
  end

  context "generating a url with a proc as the host alias" do
    setup do
      host_alias = Proc.new do |attachment|
        "hello"
      end
      @vault = create_s3_shim_vault(
        :storage => :s3,
        :s3_credentials => { :bucket => "prod_bucket" },
        :s3_host_alias => host_alias,
        :path => ":attachment/:basename.:extension",
        :url => ":s3_alias_url"
      )
    end

    should "return a url based on the host_alias" do
      assert_match %r{^http://hello/avatars/5k.png},
        @vault.url
    end

    should "still return the bucket name" do
      assert_equal "prod_bucket", @vault.bucket_name
    end
  end

  should "return a relative URL for Rails to calculate assets host" do
    vault = create_s3_shim_vault(
      :storage => :s3,
      :s3_credentials => {},
      :bucket => "bucket",
      :path => ":attachment/:basename.:extension",
      :url => ":asset_host")
    attachment = vault.instance_variable_get('@attachment')
    assert_match %r{^avatars/5k.png}, attachment.url
  end

  should "generate a secure URL with an expiration" do
    rails_env("production")
    vault = create_s3_shim_vault(
      :storage => :s3,
      :s3_credentials => {
        :production   => { :bucket => "prod_bucket" },
        :development  => { :bucket => "dev_bucket" }
      },
      :s3_host_alias => "something.something.com",
      :s3_permissions => "private",
      :path => ":attachment/:basename.:extension",
      :url => ":s3_alias_url")

    object = stub
    vault.stubs(:s3_object).returns(object)
    object.expects(:url_for).with(:read, :expires => 3600, :secure => true)

    vault.expiring_url
  end

  context "Generating a URL with an expiration for each style" do
    setup do
      rails_env("production")

      @vault = create_s3_shim_vault(
        :storage => :s3,
        :s3_credentials => {
          :production   => { :bucket => "prod_bucket" },
          :development  => { :bucket => "dev_bucket" }
        },
        :s3_permissions => :private,
        :s3_host_alias => "something.something.com",
        :path => ":attachment/:style/:basename.:extension",
        :url => ":s3_alias_url")
    end

    should "should generate a url for the thumb" do
      object = stub
      @vault.stubs(:s3_object).with(:thumb).returns(object)
      object.expects(:url_for).
        with(:read, :expires => 1800, :secure => true)

      @vault.expiring_url(1800, :thumb)
    end

    should "should generate a url for the default style" do
      object = stub
      @vault.stubs(:s3_object).with(:original).returns(object)
      object.expects(:url_for).
        with(:read, :expires => 1800, :secure => true)
      @vault.expiring_url(1800)
    end
  end

  context "Parsing S3 credentials with a bucket in them" do
    setup do
      @vault = create_s3_shim_vault(
        :storage => :s3,
        :s3_credentials => {
          :production   => { :bucket => "prod_bucket" },
          :development  => { :bucket => "dev_bucket" }
        })
    end

    should "get the right bucket in production" do
      rails_env("production")
      assert_equal "prod_bucket", @vault.bucket_name
      assert_equal "prod_bucket", @vault.s3_bucket.name
    end

    should "get the right bucket in development" do
      rails_env("development")
      assert_equal "dev_bucket", @vault.bucket_name
      assert_equal "dev_bucket", @vault.s3_bucket.name
    end
  end

  context "Parsing S3 credentials with a s3_host_name in them" do
    setup do
      @vault = create_s3_shim_vault(
        :storage => :s3,
        :bucket => 'testing',
        :s3_credentials => {
          :production   => { :s3_host_name => "s3-world-end.amazonaws.com" },
          :development  => { :s3_host_name => "s3-ap-northeast-1.amazonaws.com" }
        })
    end

    should "get the right s3_host_name in production" do
      rails_env("production")
      assert_match %r{^s3-world-end.amazonaws.com},
        @vault.s3_host_name
      assert_match %r{^s3-world-end.amazonaws.com},
        @vault.s3_bucket.config.s3_endpoint
    end

    should "get the right s3_host_name in development" do
      rails_env("development")
      assert_match %r{^s3-ap-northeast-1.amazonaws.com},
        @vault.s3_host_name
      assert_match %r{^s3-ap-northeast-1.amazonaws.com},
        @vault.s3_bucket.config.s3_endpoint
    end

    should "get the right s3_host_name if the key does not exist" do
      rails_env("test")
      assert_match %r{^s3.amazonaws.com}, @vault.s3_host_name
      assert_match %r{^s3.amazonaws.com}, @vault.s3_bucket.config.s3_endpoint
    end
  end

  context "An attachment with S3 storage" do
    setup do
      @vault = create_s3_shim_vault(
        :storage => :s3,
        :bucket => "testing",
        :path => ":attachment/:style/:basename.:extension",
        :s3_credentials => {
          'access_key_id' => "12345",
          'secret_access_key' => "54321"
        })
      file = File.new(fixture_file('5k.png'), 'rb')
      @attachment = @vault.instance_variable_get('@attachment')
      @attachment.assign(file)
      @vault.store(:original, file)
    end

    should "not get a bucket to get a URL" do
      @vault.expects(:s3).never
      @vault.expects(:s3_bucket).never
      assert_match %r{^http://s3\.amazonaws\.com/testing/avatars/original/5k\.png},
        @attachment.url
    end

    should "save" do
      object = stub
      @vault.stubs(:s3_object).returns(object)
      object.expects(:write).with(anything,
                                  :content_type => "image/png",
                                  :acl => :public_read)
      @vault.save
    end

    should "save without a bucket" do
      AWS::S3::BucketCollection.any_instance.expects(:create).with("testing")
      AWS::S3::S3Object.any_instance.stubs(:write).
        raises(AWS::S3::Errors::NoSuchBucket.new(
          stub,
          stub(:status => 404, :body => "<foo/>"))).then.returns(nil)
      @vault.save
    end

    should "remove" do
      AWS::S3::S3Object.any_instance.stubs(:exists?).returns(true)
      AWS::S3::S3Object.any_instance.stubs(:delete)
      @vault.destroy(:original => '/foo')
    end
  end

  should "get the right bucket name for a proc bucket" do
    vault = create_s3_shim_vault(
      :storage => :s3,
      :bucket => lambda { "hello" },
      :s3_credentials => {:not => :important})
    assert "hello", vault.bucket_name
  end

  should "pass on specific S3 headers" do
    vault = create_s3_shim_vault(
      :storage => :s3,
      :bucket => "testing",
      :path => ":attachment/:style/:basename.:extension",
      :s3_credentials => {
        'access_key_id' => "12345",
        'secret_access_key' => "54321"
      },
      :s3_headers => {'Cache-Control' => 'max-age=31557600'}
    )
    file = File.new(fixture_file('5k.png'), 'rb')
    vault.store(:original, file)

    s3_object = stub
    vault.stubs(:s3_object).returns(s3_object)
    s3_object.expects(:write).
      with(
        anything,
        :content_type => "image/png",
        :acl => :public_read,
        :cache_control => "max-age=31557600")

    vault.save
  end

  should "support S3 metadata using the s3_headers option" do
    vault = create_s3_shim_vault(
      :storage => :s3,
      :bucket => "testing",
      :path => ":attachment/:style/:basename.:extension",
      :s3_credentials => {
        'access_key_id' => "12345",
        'secret_access_key' => "54321"
      },
      :s3_headers => {'x-amz-meta-color' => 'red'}
    )
    file = File.new(fixture_file('5k.png'), 'rb')
    vault.store(:original, file)

    s3_object = stub
    vault.stubs(:s3_object).returns(s3_object)
    s3_object.expects(:write).
      with(
        anything,
        :content_type => "image/png",
        :acl => :public_read,
        :metadata => { "color" => "red" })

    vault.save
  end

  should "support S3 metadata using the s3_metadata option" do
    vault = create_s3_shim_vault(
      :storage => :s3,
      :bucket => "testing",
      :path => ":attachment/:style/:basename.:extension",
      :s3_credentials => {
        'access_key_id' => "12345",
        'secret_access_key' => "54321"
      },
      :s3_metadata => { "color" => "red" }
    )
    file = File.new(fixture_file('5k.png'), 'rb')
    vault.store(:original, file)

    s3_object = stub
    vault.stubs(:s3_object).returns(s3_object)
    s3_object.expects(:write).
      with(
        anything,
        :content_type => "image/png",
        :acl => :public_read,
        :metadata => { "color" => "red" })

    vault.save
  end

  should "support the S3 storage class using the headers" do
    vault = create_s3_shim_vault(
      :storage => :s3,
      :bucket => "testing",
      :path => ":attachment/:style/:basename.:extension",
      :s3_credentials => {
        'access_key_id' => "12345",
        'secret_access_key' => "54321"
      },
      :s3_headers => { "x-amz-storage-class" => "reduced_redundancy" }
    )
    file = File.new(fixture_file('5k.png'), 'rb')
    vault.store(:original, file)

    s3_object = stub
    vault.stubs(:s3_object).returns(s3_object)
    s3_object.expects(:write).
      with(
        anything,
        :content_type => "image/png",
        :acl => :public_read,
        :storage_class => "reduced_redundancy")

    vault.save
  end

  should "support the S3 storage class using the s3_storage_class option" do
    vault = create_s3_shim_vault(
      :storage => :s3,
      :bucket => "testing",
      :path => ":attachment/:style/:basename.:extension",
      :s3_credentials => {
        'access_key_id' => "12345",
        'secret_access_key' => "54321"
      },
      :s3_storage_class => :reduced_redundancy
    )
    file = File.new(fixture_file('5k.png'), 'rb')
    vault.store(:original, file)

    s3_object = stub
    vault.stubs(:s3_object).returns(s3_object)
    s3_object.expects(:write).
      with(
        anything,
        :content_type => "image/png",
        :acl => :public_read,
        :storage_class => :reduced_redundancy)

    vault.save
  end

  should "parse the credentials with S3 credentials supplied as Pathname" do
    ENV['S3_KEY']    = 'pathname_key'
    ENV['S3_BUCKET'] = 'pathname_bucket'
    ENV['S3_SECRET'] = 'pathname_secret'

    rails_env('test')

    vault = create_s3_shim_vault(
      :storage => :s3,
      :s3_credentials => Pathname.new(fixture_file('s3.yml'))
    )

    assert_equal 'pathname_bucket', vault.bucket_name
    assert_equal 'pathname_key', vault.s3_bucket.config.access_key_id
    assert_equal 'pathname_secret', vault.s3_bucket.config.secret_access_key
  end

  should "run the file through ERB with S3 credentials in a YAML file" do
    ENV['S3_KEY']    = 'env_key'
    ENV['S3_BUCKET'] = 'env_bucket'
    ENV['S3_SECRET'] = 'env_secret'

    rails_env('test')

    vault = create_s3_shim_vault(
      :storage => :s3,
      :s3_credentials => Pathname.new(fixture_file('s3.yml')))

    assert_equal 'env_bucket', vault.bucket_name
    assert_equal 'env_key', vault.s3_bucket.config.access_key_id
    assert_equal 'env_secret', vault.s3_bucket.config.secret_access_key
  end

  context "S3 Permissions" do
    should "default to public readable" do
      vault = create_s3_shim_vault(
        :storage => :s3,
        :bucket => "testing",
        :path => ":attachment/:style/:basename.:extension",
        :s3_credentials => {
          'access_key_id' => "12345",
          'secret_access_key' => "54321"
        }
      )
      file = File.new(fixture_file('5k.png'), 'rb')
      vault.store(:original, file)

      s3_object = stub
      vault.stubs(:s3_object).returns(s3_object)
      s3_object.expects(:write).
        with(anything, :content_type => "image/png", :acl => :public_read)

      vault.save
    end

    should "successfully save the object with the appropriate string permissions" do
      vault = create_s3_shim_vault(
        :storage => :s3,
        :bucket => "testing",
        :path => ":attachment/:style/:basename.:extension",
        :s3_credentials => {
          'access_key_id' => "12345",
          'secret_access_key' => "54321"
        },
        :s3_permissions => :private
      )
      file = File.new(fixture_file('5k.png'), 'rb')
      vault.store(:original, file)

      s3_object = stub
      vault.stubs(:s3_object).returns(s3_object)
      s3_object.expects(:write).
        with(anything, :content_type => "image/png", :acl => :private)

      vault.save
    end

    should "successfully save the object with the appropriate hash permissions" do
      vault = create_s3_shim_vault(
        :storage => :s3,
        :bucket => "testing",
        :path => ":attachment/:style/:basename.:extension",
        :styles => {
          :thumb => "80x80>"
        },
        :s3_credentials => {
          'access_key_id' => "12345",
          'secret_access_key' => "54321"
        },
        :s3_permissions => {
          :original => :private,
          :thumb => :public_read
        }
      )
      file = File.new(fixture_file('5k.png'), 'rb')
      vault.store(:original, file)

      s3_object = stub
      vault.stubs(:s3_object).returns(s3_object)
      vault.stubs(:private_attachment?).returns(true)
      s3_object.expects(:write)

      vault.save
      attachment = vault.instance_variable_get('@attachment')

      assert attachment.url.include?("https://")
      assert attachment.url(:thumb).include?("http://")
    end

    should "successfully save the object with the appropriate proc permissions" do
      s3_permission = Proc.new do |attachment, style|
        if style.to_sym == :thumb
          :public_read
        else
          :private
        end
      end
      vault = create_s3_shim_vault(
          :storage => :s3,
          :bucket => "testing",
          :path => ":attachment/:style/:basename.:extension",
          :styles => {
             :thumb => "80x80>"
          },
          :s3_credentials => {
            'access_key_id' => "12345",
            'secret_access_key' => "54321"
          },
          :s3_permissions => s3_permission
      )
      file = File.new(fixture_file('5k.png'), 'rb')
      vault.store(:original, file)

      s3_object = stub
      vault.stubs(:s3_object).returns(s3_object)
      vault.stubs(:private_attachment?).returns(true)
      s3_object.expects(:write)

      vault.save
      attachment = vault.instance_variable_get('@attachment')

      assert attachment.url.include?("https://")
      assert attachment.url(:thumb).include?("http://")
    end
  end
end
