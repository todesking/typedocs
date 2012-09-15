load File.join(File.dirname(__FILE__), '..', 'lib', 'typedocs.rb')

class X
  include Typedocs::DSL

  tdoc!"Numeric -> Numeric"
  def square(x)
    x * x
  end

  tdoc!"String"
  def expected_string_but_nil
    nil
  end
end

describe X do
  it do
    X.new.square(10).should == 100
  end
  it do
    expect { X.new.square('10') }.to raise_error Typedocs::ArgumentError
  end
  it do
    expect { X.new.expected_string_but_nil }.to raise_error Typedocs::RetValError
  end
end

describe Typedocs::DSL::Parser do
  describe 'src has single param: Numeric' do
    subject { Typedocs::DSL.parse('Numeric').retval_spec }
    it { should be_valid(1) }
    it { should_not be_valid('string') }
  end
  describe 'src has sinble param: String' do
    subject { Typedocs::DSL.parse('String').retval_spec }
    it { should be_valid('string') }
    it { should_not be_valid(1) }
  end

  describe 'src has two params: String, Numeric' do
    subject { Typedocs::DSL::Parser.parse('String -> Numeric') }
  end
end

