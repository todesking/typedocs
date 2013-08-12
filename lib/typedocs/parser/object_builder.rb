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
          Typedocs::MethodSpec::Single.new(
            args_spec,
            tree[:block_spec],
            tree[:return_spec] || Typedocs::ArgumentSpec::Any.new
          )
        }
        Typedocs::MethodSpec::AnyOf.new(specs)
      }

      # arg
      rule(type: simple(:t), attr: simple(:attr)) { {t: t, a: attr} }
      rule(type: simple(:t), name: dc, attr: simple(:attr)) { {t: t, a: attr} }
      # return
      rule(type: simple(:t)) { t }
      rule(type: simple(:t), name: dc) { t }

      rule(type_name: val) { as::TypeIsA.new(klass, v) }
      rule(defined_type_name: val) { as::UserDefinedType2.new(klass, v) }
      rule(any: dc) { as::Any.new }
      rule(array: simple(:v)) { as::Array.new(v) }
      rule(tuple: {types: sequence(:vs)}) { as::ArrayAsStruct.new(vs) }
      rule(hash_t: {key_t: simple(:k), val_t: simple(:v)}) { as::HashType.new(k,v) }
      rule(hash_v: {entries: subtree(:entries), anymore: simple(:anymore)}) {
        kvs = h.array(entries).map{|e|
          k = e[:key_v]
          v = e[:val_t]
          key_v =
            if k[:symbol_value]
              k[:symbol_value][:value].to_sym
            elsif k[:string_value]
              k[:string_value][:value]
            else
              raise
            end
          [key_v, v]
        }
        as::HashValue.new(kvs, !!anymore)
      }
    end
  end
end
