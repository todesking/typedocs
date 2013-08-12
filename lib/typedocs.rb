require 'strscan'

module Typedocs; end

require "typedocs/version"
require "typedocs/dsl"
require "typedocs/parser"
require "typedocs/argument_spec"
require "typedocs/arguments_spec"
require "typedocs/multi_functional_interface"
require "typedocs/context"

module Typedocs
  def self.initialize!
    @@method_specs = {}
    @@contexts = {}
  end
  initialize!

  def self.ensure_klass(obj, klass)
    raise ArgumentError, "Expected #{klass.name} but #{obj.inspect}" unless obj.kind_of?(klass)
  end

  module MethodSpec
    class AnyOf
      # [MethodSpec::Single] ->
      def initialize(specs)
        specs.each do|spec|
          Typedocs.ensure_klass(spec, Typedocs::MethodSpec::Single)
        end
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

      def to_source
        @specs.map(&:to_source).join(' || ')
      end
    end

    class Single
      # ArgumentsSpec -> ArgumentSpec -> ArgumentSpec ->
      def initialize(args_spec, block_spec, retval_spec)
        Typedocs.ensure_klass(args_spec, Typedocs::ArgumentsSpec)
        Typedocs.ensure_klass(block_spec, Typedocs::BlockSpec)
        Typedocs.ensure_klass(retval_spec, Typedocs::ArgumentSpec)
        @arguments_spec = args_spec
        @block_spec = block_spec
        @retval_spec = retval_spec
      end

      attr_reader :arguments_spec
      attr_reader :block_spec
      attr_reader :retval_spec

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
        raise Typedocs::ArgumentError, arguments_spec.error_message_for(args) unless arguments_spec.valid?(args)
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

      def to_source
        s = ''
        s << arguments_spec.to_source
        s << " -> " unless arguments_spec.empty?
        s << block_spec.to_source_with_arrow
        s << "#{retval_spec.to_source}"
      end
    end
  end

  class BlockSpec
    def initialize(type)
      @type = type
    end
    def valid?(block)
      case block
      when nil
        return @type == :opt || @type == :none
      when Proc
        return @type == :opt || @type == :req
      else
        raise 'maybe typedocs bug'
      end
    end
    def error_message_for(block)
      raise ArgumentError if valid?(block)
      case @type
      when :req
        "Block not given"
      when :none
        "Block not allowed"
      else
        raise 'maybe typedocs bug'
      end
    end
    def to_source
      case @type
      when :req
        '&'
      when :opt
        '?&'
      when :none
        ''
      else
        raise "Invalid type: #{@type}"
      end
    end
    def to_source_with_arrow
      if @type == :none
        ''
      else
        "#{to_source} -> "
      end
    end
  end

  # MethodSpec | nil
  def self.super_method_spec(klass, name)
    while klass = klass.superclass
      spec = method_spec(klass, name)
      return spec if spec
    end
    nil
  end

  def self.method_spec(klass, name)
    @@method_specs[[klass, name]]
  end

  def self.define_spec(klass, name, method_spec)
    klass.instance_eval do
      original_method = instance_method(name)
      define_method name do|*args,&block|
        method_spec.call_with_validate original_method.bind(self), *args, &block
      end
    end
    @@method_specs[[klass, name]] = method_spec
  end

  def self.create_method_spec(klass, name, tdoc_arg)
    case tdoc_arg
    when String
      Typedocs::Parser.new.parse(klass, tdoc_arg)
    when :inherit
      Typedocs.super_method_spec(klass, name) || (raise NoSuchMethod, "can't find typedoc for super method: #{klass}##{name}")
    else
      raise "Unsupported document: #{tdoc_arg.inspect}"
    end
  end

  def self.context(klass)
    @@contexts[klass] ||= Context.new(klass)
  end

  class ArgumentError < ::ArgumentError; end
  class RetValError < ::StandardError; end
  class BlockError < ::StandardError; end

  class NoSuchMethod < ::StandardError; end
  class NoSuchType < ::StandardError; end
end
