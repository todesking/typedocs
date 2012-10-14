require 'strscan'

module Typedocs; end

require "typedocs/version"
require "typedocs/dsl"
require "typedocs/parser"
require "typedocs/argument_spec"
require "typedocs/arguments_spec"

module Typedocs
  @@method_specs = {}

  module MethodSpec
    class AnyOf
      # [MethodSpec::Single] ->
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
      # ArgumentsSpec -> ArgumentSpec -> ArgumentSpec ->
      def initialize(args_spec, block_spec, retval_spec)
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
    end
  end

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

  class ArgumentError < ::ArgumentError; end
  class RetValError < ::StandardError; end
  class BlockError < ::StandardError; end
end
