require 'pp'
require "typedocs/version"
require 'strscan'

module Typedocs
  module DSL

    def self.included(klass)
      klass.extend ClassMethods

      @typedocs_current_def = nil

      class << klass
        def tdoc!(doc_str)
          @typedocs_current_def = ::Typedocs::DSL.parse doc_str
        end

        def method_added(name)
          super
          return unless @typedocs_current_def

          current_def = @typedocs_current_def
          @typedocs_current_def = nil

          ::Typedocs::DSL.decorate self, name, current_def
        end
      end
    end

    def self.parse doc
      Typedocs::DSL::Parser.new(doc).parse
    end

    def self.decorate(klass, name, tdoc_def)
      return unless tdoc_def

      klass.instance_eval do
        original_method = instance_method(name)
        define_method name do|*args|
          tdoc_def.call_with_validate original_method.bind(self), *args
        end
      end
    end

    class Parser
      def initialize src
        @src = StringScanner.new(src)
      end

      # method_spec := arg_spec? ('->' arg_spec?)*
      # arg_spec    := (spec) | spec '|' spec | atom | composite
      # atom        := type('(' value_specs ')')?
      # type        := type_name | any | dont_care | nil
      # dont_care   := '--'
      # value_specs := expression (',' expression)*
      # composite   := free_array | const_array | hash
      # free_array  := spec...
      # const_array := [spec(, spec)*]
      # hash        := {key_pattern: spec(, key_pattern: spec)*}
      # key_pattern := lit_symbol | lit_string | number
      def parse
        return read_method_spec
      end

      private
      def read_method_spec
        arg_specs = []
        until eos?
          skip_spaces

          arg_specs << read_arg_spec!

          skip_spaces
          read_allow!
        end

        arg_specs = [Validator::DontCare.instance] if arg_specs.empty?

        return MethodSpec.new arg_specs[0..-2], arg_specs[-1]
      end

      def read_arg_spec!
        if match /[A-Z]\w+\s*/ 
          klass = const_get_from ::Kernel, matched.strip
          return Validator::Type.for(klass)
        elsif match /\*\s*/
          return Validator::Any.instance
        elsif check /->/
          return Validator::DontCare.instance
        else
          raise error_message :arg_spec
        end
      end

      def read_allow!
        match /->/ || (raise error_message :allow)
      end

      def error_message expected
        "parse error(expected: #{expected}) src = #{@src.string.inspect}, error at: #{@src.string[@src.pos..(@src.pos+30)]}"
      end

      def const_get_from root, name
        name.split(/::/).inject(root) do|root, name|
          root.const_get(name.to_sym)
        end
      end

      def skip_spaces
        match /\s*/
      end

      def match pat
        @src.scan pat
      end

      def matched
        @src.matched
      end

      def check(pat)
        @src.check pat
      end

      def eos?
        @src.eos?
      end
    end
  end

  class MethodSpec
    # [Validator] -> Validator ->
    def initialize(args, ret)
      @argument_specs = args
      @retval_spec = ret
    end

    attr_reader :argument_specs
    attr_reader :retval_spec

    def argument_size
      argument_specs.size
    end

    def call_with_validate method, *args
      raise Typedocs::ArgumentError, "Argument size missmatch: expected #{argument_size} but #{args.size}" unless argument_size == args.size
      argument_specs.zip(args).each do|spec, arg|
        spec.validate_argument! arg
      end

      ret = method.call *args

      retval_spec.validate_retval! ret

      ret
    end
  end

  class Validator
    def validate_argument!(obj)
      raise Typedocs::ArgumentError, "Bad value: #{obj.inspect}" unless valid? obj
    end
    
    def validate_retval!(obj)
      raise Typedocs::RetValError, "Bad value: #{obj.inspect}" unless valid? obj
    end
    def valid?(obj)
      raise "Not implemented"
    end

    class DontCare < Validator
      def self.instance
        @instance ||= new
      end
      def valid?(obj)
        true
      end
    end

    class Any < Validator
      def self.instance
        @instance ||= new
      end
      def valid?(obj)
        true
      end
    end

    class Type < Validator
      def self.for(klass)
        new(klass)
      end

      def initialize(klass)
        @klass = klass
      end

      def valid?(obj)
        obj.is_a? @klass
      end
    end
  end

  module ClassMethods
  end

  class ArgumentError < ::ArgumentError; end
  class RetValError < ::StandardError; end
end
