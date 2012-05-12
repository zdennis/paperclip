spec_dir = File.expand_path(File.dirname(__FILE__))
helpers = Dir[File.join(spec_dir, 'support', '*')]
helpers.each {|helper| require helper}
