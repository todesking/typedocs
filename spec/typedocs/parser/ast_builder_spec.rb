require 'spec_helper'

describe Typedocs::Parser::ASTBuilder do
  def v_h(val)
    {value: val}
  end
  def type_name_h(name)
    {type_name: v_h(name) }
  end
  def named_type_h(type_name)
    {type: type_name_h(type_name)}
  end
  describe 'type' do
    subject { super().type }
    it { should parse('TypeName').as(type_name_h('TypeName')) }
    it { should parse('@DefinedTypeName').as(defined_type_name: {value: 'DefinedTypeName'}) }
    it { should parse('_').as(any: '_') }
    it { should parse('nil').as(nil_value: 'nil') }
    it { should parse('void').as(void: 'void') }
    it { should parse(':symbol_value').as(symbol_value: {value: 'symbol_value'}) }
    it { should parse('"string_value"').as(string_value: {value: 'string_value'})}
    it { should parse("'string'") }
    it { should parse('[TupleType1, TupleType2]').as(tuple: {types: [named_type_h('TupleType1'), named_type_h('TupleType2')]}) }
    it { should parse('[ArrayType...]').as(array: named_type_h('ArrayType')) }
    it { should parse('{KeyType => ValueType}').as(hash_t: {key_t: named_type_h('KeyType'), val_t: named_type_h('ValueType')}) }
    it { should parse('{:a => B}').as(hash_v: {entries: {key_v: {symbol_value: {value: 'a'}}, val_t: named_type_h('B')}, anymore: nil}) }
    it { should parse('{:a => Integer, "b" => String}').as(hash_v: {entries: [{key_v: {symbol_value: {value: 'a'}}, val_t: named_type_h('Integer')}, {key_v: {string_value: {value: 'b'}}, val_t: named_type_h('String')}], anymore: nil}) }
    it { should parse('{:a => Integer, ...}').as(hash_v: {entries: {key_v: {symbol_value: {value: 'a'}}, val_t: named_type_h('Integer')}, anymore: ', ...'}) }
    it { should parse('Type1 | Type2').as([type_name_h('Type1'), type_name_h('Type2')])}
  end

  describe 'arg_spec' do
    subject { super().arg_spec }
    it { should parse('name').as(name: v_h('name'), type: nil, attr: nil) }
    it { should parse('name:String').as(name: v_h('name'), type: type_name_h('String'), attr: nil) }
    it { should parse('name:String|nil') }
    it { should parse('data:{key:String => value:String}') }
    it { should parse('Integer').as(type: type_name_h('Integer'), attr: nil) }
    it { should parse('?String').as(type: type_name_h('String'), attr: '?') }
    it { should parse('*a:String').as(type: type_name_h('String'), name: {value: 'a'}, attr: '*') }
    it { should parse('*a').as(name: {value: 'a'}, type: nil, attr: '*') }
  end

  describe 'block_spec' do
    subject { super().block_spec }
    it { should parse('&').as(attr: nil, name: nil) }
    it { should parse('?&block').as(attr: '?', name: v_h('block')) }
  end

  describe 'method_spec' do
    subject { super().method_spec }
    let(:empty_arg_spec) { {arg_specs: [], block_spec: nil, return_spec: nil} }
    it { should parse('').as(method_spec: empty_arg_spec) }
    it { should parse('Integer').as(method_spec: {arg_specs: [], block_spec: nil, return_spec: {type: {type_name: v_h('Integer')}}}) }
    it { should parse('_ -> _') }
    it { should parse('_ ->') }
    it { should parse('& ->').as(method_spec: empty_arg_spec.merge(block_spec: {attr: nil, name: nil})) }
    it { should parse('?&b ->').as(method_spec: empty_arg_spec.merge(block_spec: {attr: '?', name: v_h('b')})) }
    it { should parse('a -> b -> & ->') }
    it { should parse('a -> b -> ?& ->') }
    it { should parse('a -> b -> &callback ->') }
    it { should parse('_ -> Integer || Integer') }
    it { should parse('_ -> _ || _ ->') }
    it { should parse('||').as(method_spec: [empty_arg_spec, empty_arg_spec]) }
  end
end
