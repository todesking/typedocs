require 'spec_helper'

describe Typedocs::Parser::ObjectBuilder do
  let(:klass) { Class.new }
  let(:parser) { Typedocs::Parser::ASTBuilder.new }
  let(:as) { Typedocs::ArgumentSpec }
  subject { Typedocs::Parser::ObjectBuilder.create_builder_for(klass) }

  def t(parser_rule_name, src, expected_klass)
    parser_rule = parser.public_send(parser_rule_name)
    subject.apply(parser_rule.parse(src)).should be_kind_of(expected_klass)
  end
  def td(parser_rule_name, src, description)
    parser_rule = parser.public_send(parser_rule_name)
    obj = subject.apply(parser_rule.parse(src))
    obj.should_not be_kind_of(Hash)
    obj.description.should == description
  end
  describe 'transform types' do
    it { t(:type, 'Integer', as::TypeIsA) }
    it { td(:type, '@X', '@X') }
    it { t(:type, '_', as::Any) }
    it { t(:type, ':a', as::Value) }
    it { t(:type, '"str"', as::Value) }
    it { t(:type, '[A, ...]', as::Array) }
    it { t(:type, '[A, B]', as::ArrayAsStruct) }
    it { t(:type, '{A => B}', as::HashType) }
    describe 'hash_v' do
      subject { super().apply(parser.type.parse('{:a => B}')) }
      it { should be_kind_of(as::HashValue) }
      its(:description) { should == '{:a => B}' }
    end
  end

  describe 'transform root' do
    it { td(:root, 'A|B', 'A|B') }
    it { td(:root, 'name:String', 'String') }
    it { td(:root, 'a -> b', '_ -> _') }
    it { td(:root, 'x:A->ret:B || a:A -> b:B -> ret:C', 'A -> B || A -> B -> C') }
    it { td(:root, 'x:X -> ?y -> *Z ->', 'X -> ?_ -> *Z -> _') }
  end
end
