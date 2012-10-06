load File.join(File.dirname(__FILE__), 'spec_helper.rb')

describe Typedocs::Parser do
  def parse(src)
    Typedocs::Parser.new(::Object, src).parse
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
    describe 'is-a(absolute name)' do
      subject { spec_for '::Numeric' }
      it { should be_valid(1) }
      it { should_not be_valid('string') }
    end
    describe 'is-a(nested name)' do
      subject { spec_for '::Object::Numeric' }
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
      subject { spec_for '_' }
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
      describe 'hash_value' do
        subject { spec_for '{:sym => Integer, "str" => String, \'str2\' => Symbol}' }
        it { should be_valid({sym: 10, "str" => "string", "str2" => :a}) }
        it { should_not be_valid({sym: 10, "str" => "string", "str2" => :a, a: 1}) }
        it { should_not be_valid({sym: 10}) }
        it { should_not be_valid(nil) }
      end
      shared_examples_for 'hash_type' do
        it { should be_valid({}) }
        it { should be_valid({'key' => 100}) }
        it { should_not be_valid({'key' => 'value'}) }
        it { should_not be_valid({:key => 100}) }
      end
      describe 'hash_type' do
        subject { spec_for '{String => Integer}' }
        it_should_behave_like 'hash_type'
      end
      describe 'named hash_type' do
        subject { spec_for '{name:String => age:Integer}' }
        it_should_behave_like 'hash_type'
      end
      # TODO: optional key
      # TODO: error if key duplicated
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
  describe 'parsing multiple validation' do
    ['Integer ->', 'Integer -> Integer', '->Integer'].each do|src|
      describe "'#{src}'" do
        subject { parse(src) }
        its(:argument_size) { should == 1 }
      end
    end
  end
end

describe Typedocs::MethodSpec do
  def parse(src)
    Typedocs::Parser.new(::Object, src).parse
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
  def ng_block(*args, &block)
    expect { ok(*args, &block) }.to raise_error Typedocs::BlockError
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
      it { ng_block(1) {|&block| block.call 1} }
    end
    describe 'Integer -> &? -> String' do
      subject { parse 'Integer -> &? -> String' }
      it { ok(1,lambda{|i|i.to_s}) {|&block| block.call 'a'} }
      it { ok(1) {|&block| 'a'} }
    end
    describe 'Integer -> Integer || String -> String' do
      subject { parse 'Integer -> Integer || String -> String' }
      it { ok(1) {|i| 2} }
      it { ok('a') {|s| 'x'} }
    end
  end
end

describe Typedocs::ArgumentSpec::TypeIsA do
  before do
    ::Object.module_eval do
      module A
        module B
          class C
          end
        end
      end
    end
  end
  after do
    ::Object.module_eval { remove_const :A }
  end
  it do
    Typedocs::ArgumentSpec::TypeIsA.new(A::B, 'C').should be_valid(A::B::C.new)
  end
  it do
    Typedocs::ArgumentSpec::TypeIsA.new(A::B, '::A::B::C').should be_valid(A::B::C.new)
  end
end

module ArgumentSpecSpecSandbox
end
describe Typedocs::ArgumentSpec do
  let(:sandbox) { ArgumentSpecSpecSandbox }
  let(:ns) { Typedocs::ArgumentSpec }
  describe '::Any' do
    subject { ns::Any.new }
    it { should be_valid(nil) }
    its(:description) { should == '_' }
    it { expect { subject.error_message_for(nil) }.to raise_error }
  end
  describe '::DontCare' do
    subject { ns::DontCare.new }
    it { should be_valid(nil) }
    its(:description) { should == '--' }
    it { expect { subject.error_message_for(nil) }.to raise_error }
  end
  describe '::TypeIsA' do
    shared_examples_for 'Integer only' do
      it { should be_valid(1) }
      it { should_not be_valid('1') }
      it { should_not be_valid(nil) }
    end
    describe 'with absolute name' do
      subject { ns::TypeIsA.new sandbox, '::Integer' }
      its(:description) { should == "::Integer" }
      it_behaves_like 'Integer only'
    end
    describe 'with relative name' do
      subject { ns::TypeIsA.new sandbox, 'Integer' }
      its(:description) { should == "Integer" }
      it_behaves_like 'Integer only'
    end
  end
  describe '::Nil' do
    subject { ns::Nil.new }
    it { should be_valid(nil) }
    it { should_not be_valid(1) }
    its(:description) { should == 'nil' }
    it { subject.error_message_for(1).should == "1 should == nil" }
  end
  describe '::ArrayAsStruct' do
    subject { ns::ArrayAsStruct.new([ns::TypeIsA.new(Object,'Integer'), ns::Nil.new]) }
    it { should be_valid([1, nil]) }
    it { should_not be_valid(1) }
    it { should_not be_valid([nil, nil]) }
    it { should_not be_valid([]) }
    it { should_not be_valid([1, nil, 1]) }
    its(:description) { should == '[Integer, nil]' }
  end
  describe '::Array' do
    subject { ns::Array.new(ns::TypeIsA.new(Object, 'Integer')) }
    it { should be_valid([]) }
    it { should be_valid([1]) }
    it { should be_valid([1,2,3]) }
    it { should_not be_valid(1) }
    it { should_not be_valid([nil]) }
    it { should_not be_valid([1,nil,2]) }
    its(:description) { should == 'Integer...' }
  end
  describe '::HashValue' do
    subject { ns::HashValue.new([[:foo, ns::TypeIsA.new(Object, 'Integer')], ['bar', ns::Nil.new]]) }
    it { should be_valid({foo: 1, 'bar' => nil}) }
    it { should_not be_valid({}) }
    it { should_not be_valid({foo: 1}) }
    it { should_not be_valid({foo: 1, 'bar' => nil, baz: 99}) }
    its(:description) { should == '{:foo => Integer, "bar" => nil}' }
  end
  describe '::HashType' do
    subject { ns::HashType.new(ns::TypeIsA.new(Object, 'Integer'), ns::TypeIsA.new(Object, 'String')) }
    it { should be_valid({1 => "a"}) }
    it { should be_valid({}) }
    it { should_not be_valid({1 => 1}) }
    it { should_not be_valid({1 => "a", 2 => 2}) }
    its(:description) { should == '{Integer => String}' }
  end
  describe '::Or' do
    describe 'when empty' do
      it { expect { ns::Or.new([]) }.to raise_error ::ArgumentError }
    end
    describe 'Integer|nil' do
      subject { ns::Or.new([ns::TypeIsA.new(Object, 'Integer'), ns::Nil.new]) }
      it { should be_valid(nil) }
      it { should be_valid(1) }
      it { should_not be_valid("str") }
      its(:description) { should == "Integer|nil" }
    end
  end
end

class ValueEquals
  def initialize(val)
    @val = val
  end
  def valid?(val)
    val == @val
  end
end
describe 'ensure ValueEquals helper works' do
  subject { ValueEquals }
  it { subject.new(1).should be_valid(1) }
  it { subject.new(1).should_not be_valid(2) }
end
describe Typedocs::ArgumentsSpec do
  def val(v)
    ValueEquals.new(v)
  end
  subject { Typedocs::ArgumentsSpec.new }
  describe 'with ()' do
    it { should be_valid([]) }
    it { should_not be_valid([:a]) }
  end
  describe 'with (a)' do
    before do
      subject.add_required(val :a)
    end
    it { should be_valid([:a]) }
    it { should_not be_valid([]) }
    it { should_not be_valid([:a,:b]) }
  end
  describe 'with (?a)' do
    before do
      subject.add_optional(val :a)
    end
    it { should be_valid([:a]) }
    it { should be_valid([]) }
    it { should_not be_valid([:a,:b]) }
  end
  describe 'with (a, ?b, ?c)' do
    before do
      subject.add_required(val :a)
      subject.add_optional(val :b)
      subject.add_optional(val :c)
    end
    it { should be_valid([:a]) }
    it { should be_valid([:a,:b]) }
    it { should be_valid([:a,:b,:c]) }
    it { should_not be_valid([:a,:b,:c,:d]) }
    it { should_not be_valid([]) }
  end
  describe 'with (*a)' do
    before do
      subject.add_rest(val :a)
    end
    it { should be_valid([]) }
    it { should be_valid([:a]) }
    it { should be_valid([:a,:a,:a]) }
    it { should_not be_valid([:a,:b]) }
  end
  describe 'with (a, *b)' do
    before do
      subject.add_required(val :a)
      subject.add_rest(val :b)
    end
    it { should be_valid([:a]) }
    it { should be_valid([:a,:b,:b]) }
    it { should_not be_valid([:a,:b,:c]) }
    it { should_not be_valid([]) }
  end
  describe 'with (*a, b)' do
    before do
      subject.add_rest(val :a)
      subject.add_required(val :b)
    end
    it { should be_valid([:b]) }
    it { should be_valid([:a, :b]) }
    it { should be_valid([:a, :a, :b]) }
    it { should_not be_valid([:a, :b, :b]) }
    it { should_not be_valid([]) }
    it { should_not be_valid([:c]) }
  end
  describe 'with (a, *b, c)' do
    before do
      subject.add_required(val :a)
      subject.add_rest(val :b)
      subject.add_required(val :c)
    end
    it { should be_valid([:a, :c]) }
    it { should be_valid([:a, :b, :c]) }
    it { should be_valid([:a, :b, :b, :c]) }
    it { should_not be_valid([:a, :b, :c, :c]) }
    it { should_not be_valid([:a]) }
  end
  describe 'with (a, ?b, c)' # error
  describe 'with (a, *b, *c)' # error
  describe 'with (a, *b, ?c)' # error
end