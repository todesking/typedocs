require 'spec_helper'

describe Typedocs::Parser::ASTBuilder do
  describe 'type' do
    subject { super().type }
    it { should parse 'TypeName' }
    it { should parse '@DefinedTypeName' }
    it { should parse '_' }
    it { should parse 'nil' }
    it { should parse 'void' }
    it { should parse ':symbol_value' }
    it { should parse '"string_value"' }
    it { should parse '[TupleType1, TupleType2]' }
    it { should parse '[ArrayType, ...]' }
    it { should parse '{KeyType => ValueType}' }
    it { should parse '{:a => Integer, "b" => String}' }
    it { should parse '{:a => Integer, "b" => String, ...}' }
    it { should parse 'Type1 | Type2' }
  end

  describe 'arg_spec' do
    subject { super().arg_spec }
    it { should parse 'name' }
    it { should parse 'name:String' }
    it { should parse 'name:String|nil' }
    it { should parse 'data:{key:String => value:String}' }
    it { should parse 'Integer' }
  end

  describe 'method_spec' do
    subject { super().method_spec }
    it { should parse '' }
    it { should parse 'Integer' }
    it { should parse '_ -> _' }
    it { should parse '_ ->' }
    it { should parse 'a -> b -> & ->' }
    it { should parse 'a -> b -> ?& ->' }
    it { should parse 'a -> b -> &callback ->' }
    it { should parse '_ -> Integer || Integer' }
    it { should parse '_ -> _ || _ ->' }
  end
end
