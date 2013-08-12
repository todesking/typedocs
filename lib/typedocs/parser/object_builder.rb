class Typedocs::Parser; end

require 'parslet'
require 'typedocs/type_spec'

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
          return_spec = tree[:return_spec] || Typedocs::TypeSpec::Any.new
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
      rule(void: dc) { ts::DontCare.new }
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
