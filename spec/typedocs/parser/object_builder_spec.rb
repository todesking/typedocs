require 'spec_helper'

describe Typedocs::Parser::ObjectBuilder do
  let(:klass) { Class.new }
  let(:parser) { Typedocs::Parser::ASTBuilder.new }
  subject { Typedocs::Parser::ObjectBuilder.create_builder_for(klass) }

  def t(parser_rule, src)
    subject.apply parser.public_send(parser_rule).parse(src)
  end

  it { t(:type, 'Integer').should be_is_a(Typedocs::ArgumentSpec::TypeIsA) }
end
