# coding: utf-8
require 'spec_helper'

describe TypableMap do
  before do
    @timeline = TypableMap.new(50*50,true)
    @tid = @timeline.push :value_01
  end  
  subject { @timeline[@tid] }
  it { should eq :value_01 }
end
