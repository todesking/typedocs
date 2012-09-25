load File.join(File.dirname(__FILE__), '..', 'lib', 'typedocs.rb')

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
      describe 'hash_value' do
        subject { spec_for '{:symbol_key => Integer, "string_key" => String}' }
        it { should be_valid({symbol_key: 10, "string_key" => "string"}) }
        it { should_not be_valid({symbol_key: 10, "string_key" => "string", a: 1}) }
        it { should_not be_valid({symbol_key: 10}) }
        it { should_not be_valid(nil) }
      end
      describe 'hash_type' do
        subject { spec_for '{String => Integer}' }
        it { should be_valid({}) }
        it { should be_valid({'key' => 100}) }
        it { should_not be_valid({'key' => 'value'}) }
        it { should_not be_valid({:key => 100}) }
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

describe Typedocs::Validator::Type do
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
    Typedocs::Validator::Type.new(A::B, 'C').should be_valid(A::B::C.new)
  end
  it do
    Typedocs::Validator::Type.new(A::B, '::A::B::C').should be_valid(A::B::C.new)
  end
end
