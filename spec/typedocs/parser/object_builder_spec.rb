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
  describe 'transform types' do
    it { t(:type, 'Integer', as::TypeIsA) }
    it { t(:type, '@X', as::UserDefinedType2) }
    it { t(:type, '_', as::Any) }
    it { pending('NIMPL'); t(:type, ':a', as::Value) }
    it { pending('NIMPL'); t(:type, '"str"', as::Value) }
    it { t(:type, '[A, ...]', as::Array) }
    it { t(:type, '[A, B]', as::ArrayAsStruct) }
    it { t(:type, '{A => B}', as::HashType) }
    describe 'hash_v' do
      subject { super().apply(parser.type.parse('{:a => B}')) }
      it { should be_kind_of(as::HashValue) }
      its(:description) { should == '{:a => B}' }
    end
  end
end
