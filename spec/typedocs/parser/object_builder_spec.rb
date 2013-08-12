require 'spec_helper'

describe Typedocs::Parser::ObjectBuilder do
  let(:klass) { Class.new }
  let(:parser) { Typedocs::Parser::ASTBuilder.new }
  let(:ts) { Typedocs::TypeSpec }
  subject { Typedocs::Parser::ObjectBuilder.create_builder_for(klass) }

  def t(parser_rule_name, src, expected_klass)
    parser_rule = parser.public_send(parser_rule_name)
    subject.apply(parser_rule.parse(src)).should be_kind_of(expected_klass)
  end
  def td(parser_rule_name, src, to_source)
    parser_rule = parser.public_send(parser_rule_name)
    obj = subject.apply(parser_rule.parse(src))
    obj.should_not be_kind_of(Hash)
    obj.to_source.should == to_source
  end
  describe 'transform types' do
    it { t(:type, 'Integer', ts::TypeIsA) }
    it { td(:type, '@X', '@X') }
    it { t(:type, '_', ts::Any) }
    it { t(:type, ':a', ts::Value) }
    it { t(:type, '"str"', ts::Value) }
    it { t(:type, '[A...]', ts::Array) }
    it { t(:type, '[A, B]', ts::ArrayAsStruct) }
    it { t(:type, '{A => B}', ts::HashType) }
    describe 'hash_v' do
      subject { super().apply(parser.type.parse('{:a => B}')) }
      it { should be_kind_of(ts::HashValue) }
      its(:to_source) { should == '{:a => B}' }
    end
  end

  describe 'transform root' do
    it { td(:root, 'A|B', 'A|B') }
    it { td(:root, 'name:String', 'name:String') }
    it { td(:root, 'a -> b', 'a:_ -> b:_') }
    it { td(:root, 'x:A->ret:B || a:A -> b:B -> ret:C', 'x:A -> ret:B || a:A -> b:B -> ret:C') }
    it { td(:root, 'x:X -> ?y -> *Z ->', 'x:X -> ?y:_ -> *Z -> _') }
    it { td(:root, 'a -> ?&b ->', 'a:_ -> ?&b -> _') }
  end
end
