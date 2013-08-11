require 'spec_helper'

describe Typedocs::Parser::ASTBuilder do
  describe 'type' do
    subject { super().type }
    def type_name_h(name)
      {type_name: {value: name}}
    end
    def arg_spec_h(type_name)
      {type: type_name_h(type_name)}
    end
    it { should parse('TypeName').as(type_name_h('TypeName')) }
    it { should parse('@DefinedTypeName').as(defined_type_name: {value: 'DefinedTypeName'}) }
    it { should parse('_').as(any: '_') }
    it { should parse('nil').as(nil_value: 'nil') }
    it { should parse('void').as(void: 'void') }
    it { should parse(':symbol_value').as(symbol_value: {value: 'symbol_value'}) }
    it { should parse('"string_value"').as(string_value: {value: 'string_value'})}
    it { should parse('[TupleType1, TupleType2]').as(tuple: {types: [arg_spec_h('TupleType1'), arg_spec_h('TupleType2')]}) }
    it { should parse('[ArrayType, ...]').as(array: arg_spec_h('ArrayType')) }
    it { should parse('{KeyType => ValueType}').as(hash_t: {key_t: arg_spec_h('KeyType'), val_t: arg_spec_h('ValueType')}) }
    it { should parse('{:a => Integer, "b" => String}').as(hash_v: {entries: [{key_v: {symbol_value: {value: 'a'}}, val_t: arg_spec_h('Integer')}, {key_v: {string_value: {value: 'b'}}, val_t: arg_spec_h('String')}]}) }
    it { should parse('{:a => Integer, ...}').as(hash_v: {entries: {key_v: {symbol_value: {value: 'a'}}, val_t: arg_spec_h('Integer')}, anymore: '...'}) }
    it { should parse('Type1 | Type2').as([type_name_h('Type1'), type_name_h('Type2')])}
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
