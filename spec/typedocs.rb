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

Typedocs::DSL.do_nothing
class Unchecked
  include Typedocs::DSL

  tdoc!"Integer"
  def not_integer
    nil
  end
end

Typedocs::DSL.do_anything

describe do
  it do
    Unchecked.new.not_integer.should == nil
  end
end

describe Typedocs::Parser do
  def parse(src)
    Typedocs::Parser.new(src).parse
  end
  describe 'parsing single validation' do
    def spec_for(src)
      parse(src).retval_spec
    end
    describe 'is-a' do
      subject { spec_for 'Numeric' }
      it { should be_valid(1) }
      it { should_not be_valid('string') }
    end
    describe 'dont care(implicit)' do
      subject { spec_for '' }
      it { should be_valid(1) }
      it { should be_valid(nil) }
    end
    describe 'dont carre(explicit)' do
      subject { spec_for '--' }
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
    describe '...' do
      subject { spec_for 'Integer...' }
      it { should be_valid([1,2,3]) }
      it { should be_valid([]) }
      it { should_not be_valid(['a']) }
    end
    describe 'Hash' do
      describe 'empty' do
        subject { spec_for '{}' }
        it { should be_valid({}) }
        it { should_not be_valid({1 => 2}) }
      end
      describe 'key-value' do
        subject { spec_for '{symbol_key: Integer, "string_key": String}' }
        it { should be_valid({symbol_key: 10, "string_key" => "string"}) }
        it { should_not be_valid({symbol_key: 10, "string_key" => "string", a: 1}) }
        it { should_not be_valid({symbol_key: 10}) }
        it { should_not be_valid(nil) }
      end
      # optional key
      # error if key duplicated
    end
    # name:spec style
  end
  describe 'parsing method specification with block' do
    describe 'Integer -> & -> String' do
      subject { parse 'Integer -> & -> String' }
      its(:block_spec) { should_not be_nil }
      it { subject.block_spec.should_not be_valid(nil) }
      it { subject.block_spec.should be_valid(lambda{}) }
    end
    describe 'Invalid syntax' do
      it do
        expect { parse 'Integer -> & -> Integer -> String' }.to raise_error
      end
    end
  end
end

describe Typedocs::MethodSpec do
  def parse(src)
    Typedocs::Parser.new(src).parse
  end
  def ok(*args,&block)
    case args.last
    when Proc
      subject.call_with_validate(block, *args[0..-2], &args.last)
    else
      subject.call_with_validate(block, *args)
    end
    # should not raise any exceptions
  end
  def ng_arg(*args, &block)
    expect { ok(*args, &block) }.to raise_error Typedocs::ArgumentError
  end
  def ng_ret(*args, &block)
    expect { ok(*args, &block) }.to raise_error Typedocs::RetValError
  end
  describe 'validation' do
    describe 'retval is Integer' do
      subject { parse('Integer') }
      it { ok { 1 } }
      it { ng_ret { nil } }
      it { ng_ret { '1' } }
    end
    describe 'retval is Integer or nil' do
      subject { parse 'Integer|nil' }
      it { ok { 1 } }
      it { ok { nil } }
      it { ng_ret { '1' } }
    end
    describe 'Integer -> Integer' do
      subject { parse 'Integer -> Integer' }
      it { ok(1) {|i| i} }
      it { ng_arg(nil) { nil } }
      it { ng_ret(1) { nil } }
    end
    describe 'Integer -> --(dont care)' do
      subject { parse 'Integer -> --' }
      it { ok(1) {1} }
      it { ng_arg(nil) {1} }
    end
    describe 'Integer -> & -> String' do
      subject { parse 'Integer -> & -> String' }
      it { ok(1,lambda{|i|i.to_s}) {|&block| block.call 1} }
      it { ng_arg(1) {|&block| block.call 1} }
    end
  end
end

