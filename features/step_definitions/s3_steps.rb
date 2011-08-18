Given /I validate my S3 credentials/ do
  key = ENV['AWS_ACCESS_KEY_ID']
  secret = ENV['AWS_SECRET_ACCESS_KEY']
  bucket = ENV['PAPERCLIP_TEST_BUCKET']

  key.should_not be_nil
  secret.should_not be_nil
  bucket.should_not be_nil

  assert_credentials(key, secret, bucket)
end
