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

  tdoc!"Numeric -> [Integer,String]"
  def return_pair(num)
    [num.to_i, num.to_s]
  end

  tdoc!"[]"
  def return_empty_array
    []
  end

  tdoc!"* -> String | Integer"
  def return_int_or_string(is_str)
    is_str ? 'string' : 100
  end

  tdoc!"nil"
  def return_nil
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
  it do
    X.new.return_pair(1).should == [1, '1']
  end

  it do
    X.new.return_empty_array.should == []
  end

  it do
    X.new.return_int_or_string(true).should == 'string'
    X.new.return_int_or_string(false).should == 100
  end
  it do
    X.new.return_nil.should == nil
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
    describe 'Array(as struct)' do
      subject { spec_for '[String, Symbol]' }
      it { should be_valid(['hoge', :foo]) }
      it { should_not be_valid(['hoge', 'hoge']) }
      it { should_not be_valid([nil, :foo]) }
      it { should_not be_valid(['hoge', :foo, :bar]) }

      describe 'when empty' do
        subject { spec_for '[]' }
        it { should be_valid([]) }
        it { should_not be_valid([nil]) }
      end
    end
    describe 'OR' do
      subject { spec_for 'String | Symbol | Integer' }
        it { should be_valid('s') }
        it { should be_valid(:aaa) }
        it { should be_valid(100) }
        it { should_not be_valid(1.0) }
    end
    describe 'nil' do
      subject { spec_for 'nil' }
      it { should be_valid(nil) }
      it { should_not be_valid(1) }
    end
  end
end

