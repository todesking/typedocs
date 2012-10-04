require 'strscan'

module Typedocs; end

require "typedocs/version"
require "typedocs/dsl"
require "typedocs/parser"

module Typedocs
  module MethodSpec
    class Any
      # [Single] ->
      def initialize(specs)
        @specs = specs
      end

      def call_with_validate(method, *args, &block)
        spec = nil
        @specs.each do|s|
          begin
            s.validate_caller(args, block)
            spec = s
            break
          rescue Typedocs::ArgumentError, Typedocs::BlockError
          end
        end

        unless spec
          raise Typedocs::ArgumentError, "Arguments not match any rule"
        end

        ret = method.call(*args, &block)
        spec.validate_retval ret
        ret
      end
    end

    class Single
      # [Validator] -> Validator -> Validator ->
      def initialize(args, block, ret)
        @argument_specs = args
        @block_spec = block
        @retval_spec = ret
      end

      attr_reader :argument_specs
      attr_reader :block_spec
      attr_reader :retval_spec

      def argument_size
        argument_specs.size
      end

      def call_with_validate(method, *args, &block)
        validate_args args
        validate_block block
        ret = method.call *args, &block
        validate_retval ret
        ret
      end

      def validate_caller(args, block)
        validate_args args
        validate_block block
      end

      def validate_args(args)
        raise Typedocs::ArgumentError, "Argument size missmatch: expected #{argument_size} but #{args.size}" unless argument_size == args.size
        argument_specs.zip(args).each do|spec, arg|
          raise Typedocs::ArgumentError,spec.error_message_for(arg) unless spec.valid?(arg)
        end
      end

      def validate_block(block)
        raise Typedocs::BlockError, "Cant accept block" if !block_spec && block
        if block_spec
          raise Typedocs::BlockError, block_spec.error_message_for(block) unless block_spec.valid?(block)
        end
      end

      def validate_retval(ret)
        raise Typedocs::RetValError, retval_spec.error_message_for(ret) unless retval_spec.valid?(ret)
      end
    end
  end

  class ArgumentsSpec
    def initialize
      @arguments = []
      @min_len = 0
      @max_len = 0
      @required_head_len = 0
      @required_tail_len = 0
      @has_rest = false
    end
    def valid?(args)
      return false unless (@min_len..@max_len).include? args.length
      args[0...@required_head_len].zip(@arguments).each do|arg, (type, spec)|
        return false unless spec.valid?(arg)
      end
      if @has_rest
        rest_spec = @arguments[@required_head_len][1]
        rest_args = if @required_tail_len > 0
                      args[@required_head_len...-@required_tail_len]
                    else
                      args[@required_head_len..-1]
                    end
        rest_args.each do|arg|
          return false unless rest_spec.valid? arg
        end
      end
      if @required_tail_len > 0
        args[-@required_tail_len..-1].zip(@arguments[-@required_tail_len..-1]).each do|arg, (type, spec)|
          return false unless spec.valid?(arg)
        end
      end
      return true
    end
    def add_required(arg_spec)
      @arguments.push [:req, arg_spec]
      @min_len += 1
      @max_len += 1
      if @has_rest
        @required_tail_len += 1
      else
        @required_head_len += 1
      end
    end
    def add_optional(arg_spec)
      @arguments.push [:opt, arg_spec]
      @max_len += 1
    end
    def add_rest(arg_spec)
      @arguments.push [:rest, arg_spec]
      @max_len = Float::INFINITY
      @has_rest = true
    end
  end

  class ArgumentSpec
    def error_message_for(obj)
      "Expected #{self.description}, but #{obj.inspect}"
    end
    class Any < ArgumentSpec
      def valid?(arg); true; end
      def description; '_'; end
      def error_message_for(arg)
        raise "This spec accepts ANY value"
      end
    end
    class DontCare < Any
      def description; '--'; end
    end
    class TypeIsA < ArgumentSpec
      def initialize(klass, name)
        @klass = klass
        @name = name
      end
      def target_klass
        @target_klass ||= find_const @klass, @name
      end
      def valid?(arg);
        arg.is_a? target_klass
      end
      def description
        @name
      end
      private
      def find_const(start, name)
        raise ::ArgumentError, 'name' if name.empty?
        raise ::ArgumentError, 'start' unless start
        case name
        when /^::/
          const_get_from! ::Object, name
        else
          candidates = []
          candidates << const_get_from(start, name)
          candidates << const_get_with_nested(start, name)
          candidates = candidates.reject(&:nil?).uniq
          raise ::ArgumentError, "Type name #{name} is ambigious(search base: #{start}): #{candidates.map(&:name).join(' and ')}" if candidates.size > 1
          raise ::ArgumentError, "Type not found: #{name}(search base: #{start})" unless candidates.size == 1
          candidates.first
        end
      end
      def const_get_with_nested(start, name)
        top = name.split(/::/).first
        root = start
        until root.nil?
          return const_get_from(root, name) if root.const_defined?(top, false)
          root = parent_nest(root)
        end
        nil
      end
      def parent_nest(klass)
        return nil unless klass.name =~ /::/
        name = klass.name.split(/::/)[0..-2].join('::')
        const_get_from ::Object, name
      end
      def const_get_from(root, name)
        begin
          const_get_from! root, name
        rescue NameError
          nil
        end
      end
      def const_get_from!(root, name)
        name.gsub(/^::/,'').split(/::/).inject(root) do|root, name|
          root.const_get(name.to_sym)
        end
      rescue NameError => e
        raise NameError, "NameError: #{name.inspect}"
      end
    end
    class Nil < ArgumentSpec
      def initialize
        @value = nil
      end
      def valid?(obj)
        obj == @value
      end
      def description
        @value.inspect
      end
      def error_message_for(obj)
        "#{obj} should == #{@value.inspect}"
      end
    end
    class ArrayAsStruct < ArgumentSpec
      def initialize(specs)
        @specs = specs
      end
      def valid?(obj)
        obj.is_a?(::Array) &&
        @specs.size == obj.size &&
        @specs.zip(obj).all?{|spec,elm| spec.valid?(elm)}
      end
      def description
        "[#{@specs.map(&:description).join(', ')}]"
      end
    end
    class Array < ArgumentSpec
      def initialize(spec)
        @spec = spec
      end
      def valid?(obj)
          obj.is_a?(::Array) && obj.all?{|elm| @spec.valid?(elm)}
      end
      def description
        "#{@spec.description}..."
      end
    end
    class HashValue < ArgumentSpec
      # [key, spec]... ->
      def initialize(entries)
        @entries = entries
      end
      def valid?(obj)
        obj.is_a?(::Hash) &&
        @entries.size == obj.size &&
        @entries.all? {|key, spec| obj.has_key?(key) && spec.valid?(obj[key]) }
      end
      def description
        "{#{@entries.map{|key,value| "#{key.inspect} => #{value.description}"}.join(', ')}}"
      end
    end
    class HashType < ArgumentSpec
      def initialize(key_spec, value_spec)
        @key_spec = key_spec
        @value_spec = value_spec
      end
      def valid?(obj)
        obj.is_a?(::Hash) &&
          obj.keys.all?{|k| @key_spec.valid? k} &&
          obj.values.all?{|v| @value_spec.valid? v}
      end
      def description
        "{#{@key_spec.description} => #{@value_spec.description}}"
      end
    end
    class Or < ArgumentSpec
      def initialize(children)
        raise ArgumentError, "Children is empth" if children.empty?
        @children = children
      end
      def valid?(obj)
        @children.any?{|spec| spec.valid? obj}
      end
      def description
        "#{@children.map(&:description).join('|')}"
      end
    end
  end

  class ArgumentError < ::ArgumentError; end
  class RetValError < ::StandardError; end
  class BlockError < ::StandardError; end
end
