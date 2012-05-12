require 'spec_helper'
require 'paperclip/processor'

describe Paperclip::Processor do
  it 'instantiates and calls #make when sent .make' do
    result = InheritedProcessor.make(:one, :two, :three)
    result.should == [:one, :two, :three]
  end
end

class InheritedProcessor < Paperclip::Processor
  def make
    [@file, @options, @attachment]
  end
end
