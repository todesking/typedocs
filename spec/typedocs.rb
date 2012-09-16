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
  def spec_for(src)
    Typedocs::DSL.parse(src).retval_spec
  end
  describe 'parsing arg/retval spec' do
    describe 'is-a' do
      subject { spec_for 'Numeric' }
      it { should be_valid(1) }
      it { should_not be_valid('string') }
    end
    describe 'dont care' do
      subject { spec_for '' }
      it { should be_valid(1) }
      it { should be_valid(nil) }
    end
    describe 'anything' do
      subject { spec_for '*' }
      it { should be_valid(1) }
      it { should be_valid(nil) }
    end
  end
end

