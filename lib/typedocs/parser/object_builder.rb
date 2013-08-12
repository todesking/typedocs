class Typedocs::Parser; end

require 'parslet'
require 'typedocs/argument_spec'

class Typedocs::Parser::ObjectBuilder
  module Helper
    def self.array(a)
      case a
      when Array
        a
      else
        [a]
      end
    end
  end
  def self.create_builder_for(klass)
    Parslet::Transform.new do
      val = {value: simple(:v)}
      as = Typedocs::ArgumentSpec
      h = Helper
      dc = subtree(:_) # dont care
      dc2 = subtree(:__)
      mktype = ->(t) {
        case t
        when Array
          as::Or.new(t)
        else
          t
        end
      }

      rule(method_spec: subtree(:ms)) {
        specs = h.array(ms).map {|tree|
          args_spec = Typedocs::ArgumentsSpec.new
          tree[:arg_specs].each do|as|
            type = as[:t] || Typedocs::ArgumentSpec::Any.new
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
          return_spec = tree[:return_spec] || Typedocs::ArgumentSpec::Any.new
          block_spec =
            if !tree[:block_spec]
              Typedocs::BlockSpec.new(:none)
            elsif tree[:block_spec][:attr] == '?'
              Typedocs::BlockSpec.new(:opt)
            else
              Typedocs::BlockSpec.new(:req)
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
      rule(type: subtree(:t), attr: simple(:attr)) { {t: mktype[t], a: attr} }
      rule(type: subtree(:t), name: dc, attr: simple(:attr)) { {t: mktype[t], a: attr} }
      # return
      rule(type: subtree(:t)) { mktype[t] }
      rule(type: subtree(:t), name: dc) { mktype[t] }

      rule(type_name: val) { as::TypeIsA.new(klass, v.to_s) }
      rule(defined_type_name: val) { as::UserDefinedType.new(klass, "@#{v.to_s}") }
      rule(any: dc) { as::Any.new }
      rule(void: dc) { as::DontCare.new }
      rule(array: simple(:v)) { as::Array.new(v) }
      rule(tuple: {types: subtree(:vs)}) { as::ArrayAsStruct.new(vs) }
      rule(hash_t: {key_t: simple(:k), val_t: simple(:v)}) { as::HashType.new(k,v) }
      rule(hash_v: {entries: subtree(:entries), anymore: simple(:anymore)}) {
        kvs = h.array(entries).map{|e|
          k = e[:key_v]
          v = e[:val_t]
          key_v = k.value
          [key_v, v]
        }
        as::HashValue.new(kvs, !!anymore)
      }

      rule(string_value: val) { as::Value.new(v.to_s) }
      rule(symbol_value: val) { as::Value.new(v.to_sym) }
      rule(nil_value: dc) { as::Value.new(nil) }
    end
  end
end
