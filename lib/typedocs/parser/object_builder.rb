class Typedocs::Parser; end

require 'parslet'
require 'typedocs/type_spec'
require 'patm'

class Typedocs::Parser::ObjectBuilder
  extend Patm::DSL

  def self.create_builder_for(klass)
    new(klass)
  end

  def initialize(klass)
    @klass = klass
  end

  attr_reader :klass

  def apply(ast)
    create_method_spec(ast)
  end

  P = Patm
  T = Typedocs
  TS = Typedocs::TypeSpec
  BUG = lambda {|ast, _| raise "BUG: Invalid AST: #{ast.inspect}" }
  module H
    def self.array(a)
      case a
      when Array
        a
      else
        [a]
      end
    end
  end

  _1 = P._1
  _2 = P._2
  _ = P._any

  define_matcher :create_method_spec do|r|
    r.on(method_spec: _1) do|m, _self|
      specs = H.array(m._1).map{|spec1| _self.create_method_spec1(spec1) }
      if specs.size > 1
        T::MethodSpec::AnyOf.new(specs)
      else
        specs.first
      end
    end
    r.else(&BUG)
  end

  define_matcher :create_method_spec1 do|r|
    r.on(
      arg_specs:   _[:args],
      block_spec:  _[:blk].opt,
      return_spec: _[:ret].opt,
    ) do|m, _self|
      T::MethodSpec::Single.new(
        _self.create_args_spec(m[:args]),
        _self.create_block_spec(m[:blk]),
        _self.create_return_spec(m[:ret])
      )
    end
    r.else(&BUG)
  end

  def create_args_spec(args)
    spec = T::ArgumentsSpec.new
    args.each do|a|
      type = create_named_type(a)
      case a[:attr]
      when nil
        spec.add_required(type)
      when '*'
        spec.add_rest(type)
      when '?'
        spec.add_optional(type)
      else
        raise "arg_spec: Unknown attr: #{a[:attr].inspect}"
      end
    end
    spec
  end

  define_matcher :create_named_type do|r|
    r.on(name: _[:name].opt, type: _[:type].opt) do|m, _self|
      unnamed = _self.create_unnamed_type(m[:type])
      if m[:name]
        TS::Named.new(m[:name], unnamed)
      else
        unnamed
      end
    end
    r.else(&BUG)
  end

  define_matcher :create_unnamed_type do|r|
    val = {value: _1}
    # TODO: fixed in patm 2.0.1
    r.on(_1&Patm::Pattern.build_from(Array)) {|m, _self|
      TS::Or.new(m._1.map{|t| _self.create_named_type(t) }) }

    r.on(type_name: val) {|m, _s| TS::TypeIsA.new(_s.klass, m._1.to_s) }
    r.on(defined_type_name: val) {|m, _s|
      TS::UserDefinedType.new(_s.klass, "@#{m._1.to_s}") }

    r.on(any: _) { TS::Any.new }
    r.on(void: _) { TS::Void.new }

    r.on(array: _1) {|m, _s| TS::Array.new(_s.create_named_type(m._1)) }
    r.on(tuple: {types: _1}) {|m, _s|
      TS::ArrayAsStruct.new(m._1.map{|t| _s.create_named_type(t) }) }

    r.on(hash_t: {key_t: _1, val_t: _2}) {|m, _s|
      TS::HashType.new(_s.create_named_type(m._1), _s.create_named_type(m._2)) }
    r.on(hash_v: {entries: _[:entries], anymore: _[:anymore]}) {|m, _s|
      TS::HashValue.new(
        H.array(m[:entries]).map {|e|
          [_s.extract_value(e[:key_v]), _s.create_named_type(e[:val_t])]
        },
        !!m[:anymore]
      )
    }
    r.on(nil_value: _) { TS::Value.new(nil) }
    r.on(string_value: val) {|m| TS::Value.new(m._1.to_s) }
    r.on(symbol_value: val) {|m| TS::Value.new(m._1.to_sym) }

    r.on(nil) { TS::Any.new }

    r.else(&BUG)
  end

  def extract_value(ast)
    t = create_unnamed_type(ast)
    if t.is_a?(TS::Value)
      t.value
    else
      BUG.call(ast)
    end
  end

  define_matcher :create_block_spec do|r|
    r.on(nil) { T::BlockSpec.new(:none, nil) }
    r.on(name: P.or(nil, {value: _1}), attr: _2.opt) {|m, _s|
      case m._2
      when nil
        T::BlockSpec.new(:req, _1)
      when '?'
        T::BlockSpec.new(:opt, _1)
      else
        BUG.call(m._2)
      end
    }
    r.else(&BUG)
  end

  define_matcher :create_return_spec do|r|
    r.on(nil) { T::TypeSpec::Void.new }
    r.else {|obj, _s| _s.create_named_type(obj) }
  end

  def self.foo
    Parslet::Transform.new do
      val = {value: simple(:v)}
      ts = Typedocs::TypeSpec
      h = Helper
      dc = subtree(:_) # dont care
      dc2 = subtree(:__)
      mktype = ->(t, name) {
        unnamed =
          case t
          when Array
            ts::Or.new(t)
          else
            t || ts::Any.new
          end
        if name
          ts::Named.new(name, unnamed)
        else
          unnamed
        end
      }

      rule(method_spec: subtree(:ms)) {
        specs = h.array(ms).map {|tree|
          args_spec = Typedocs::ArgumentsSpec.new
          tree[:arg_specs].each do|as|
            type = as[:t] || Typedocs::TypeSpec::Any.new
            case as[:a]
            when '*'
              args_spec.add_rest(type)
            when '?'
              args_spec.add_optional(type)
            when nil
              args_spec.add_required(type)
            else
              raise "Unknown attr: #{as[:a].inspect}"
            end
          end
          return_spec = tree[:return_spec] || Typedocs::TypeSpec::Void.new
          block_spec =
            tree[:block_spec].tap do|bs|
              break Typedocs::BlockSpec.new(:none, nil) if !bs
              name = bs[:name] ? bs[:name][:value] : nil
              if bs[:attr] == '?'
                break Typedocs::BlockSpec.new(:opt, name)
              else
                break Typedocs::BlockSpec.new(:req, name)
              end
            end
          Typedocs::MethodSpec::Single.new(args_spec, block_spec, return_spec)
        }
        if specs.size > 1
          Typedocs::MethodSpec::AnyOf.new(specs)
        else
          specs.first
        end
      }

      # arg
      rule(type: subtree(:t), attr: simple(:attr)) { {t: mktype[t, nil], a: attr} }
      rule(type: subtree(:t), name: {value: simple(:name)}, attr: simple(:attr)) { {t: mktype[t, name], a: attr} }
      # return
      rule(type: subtree(:t)) { mktype[t, nil] }
      rule(type: subtree(:t), name: {value: simple(:name)}) { mktype[t, name] }

      rule(type_name: val) { ts::TypeIsA.new(klass, v.to_s) }
      rule(defined_type_name: val) { ts::UserDefinedType.new(klass, "@#{v.to_s}") }
      rule(any: dc) { ts::Any.new }
      rule(void: dc) { ts::Void.new }
      rule(array: simple(:v)) { ts::Array.new(v) }
      rule(tuple: {types: subtree(:vs)}) { ts::ArrayAsStruct.new(vs) }
      rule(hash_t: {key_t: simple(:k), val_t: simple(:v)}) { ts::HashType.new(k,v) }
      rule(hash_v: {entries: subtree(:entries), anymore: simple(:anymore)}) {
        kvs = h.array(entries).map{|e|
          k = e[:key_v]
          v = e[:val_t]
          key_v = k.value
          [key_v, v]
        }
        ts::HashValue.new(kvs, !!anymore)
      }

      rule(string_value: val) { ts::Value.new(v.to_s) }
      rule(symbol_value: val) { ts::Value.new(v.to_sym) }
      rule(nil_value: dc) { ts::Value.new(nil) }
    end
  end
end
