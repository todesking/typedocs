require 'pp'
require "typedocs/version"
require 'strscan'

module Typedocs

  module DSL
    @enabled = true

    def self.do_nothing
      @enabled = false
    end

    def self.do_anything
      @enabled = true
    end

    def self.enabled?
      @enabled
    end

    def self.included(klass)
      klass.extend ClassMethods

      @typedocs_current_def = nil

      if Typedocs::DSL.enabled?
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

          def singleton_method_added(name)
            super
            return unless @typedocs_current_def

            current_def = @typedocs_current_def
            @typedocs_current_def = nil

            singleton_class = class << self; self; end
            ::Typedocs::DSL.decorate singleton_class, name, current_def
          end
        end
      else
        class << klass
          def tdoc!(doc_str); end
        end
      end
    end

    def self.parse doc
      Typedocs::Parser.new(doc).parse
    end

    def self.decorate(klass, name, tdoc_def)
      return unless tdoc_def

      klass.instance_eval do
        original_method = instance_method(name)
        define_method name do|*args,&block|
          tdoc_def.call_with_validate original_method.bind(self), *args, &block
        end
      end
    end
  end

  class Parser
    def initialize src
      @src = StringScanner.new(src)
    end

    # This is blueprint, not specification of current state.
    #   method_spec := arg_spec? ('->' arg_spec?)*
    #   arg_spec    := (spec) | spec '|' spec | atom | composite
    #   atom        := type('(' value_specs ')')?
    #   type        := type_name | any | dont_care | nil
    #   dont_care   := '--'
    #   value_specs := expression (',' expression)*
    #   composite   := array | struct_array | hash
    #   array  := spec...
    #   struct_array := [spec(, spec)*]
    #   hash        := {key_pattern: spec(, key_pattern: spec)*}
    #   key_pattern := '?'? ( lit_symbol | lit_string | number )
    def parse
      return read_method_spec!
    end

    private
    def read_method_spec!
      specs = []
      begin
        skip_spaces
        specs << read_method_spec_single!
        skip_spaces
      end while match /\|\|/

      skip_spaces
      raise error_message :eos unless eos?

      if specs.size == 1
        return specs.first
      else
        MethodSpec::Any.new(specs)
      end
    end

    def read_method_spec_single!
      arg_specs = []
      block_spec = nil

      arg_specs << read_arg_spec!
      skip_spaces
      while read_arrow
        skip_spaces

        block_spec = read_block_spec
        if block_spec
          skip_spaces
          read_arrow!
          skip_spaces
          arg_specs << read_arg_spec!
          skip_spaces
          break
        end

        arg_specs << read_arg_spec!

        skip_spaces
      end
      skip_spaces

      arg_specs = [Validator::DontCare.instance] if arg_specs.empty?

      return MethodSpec::Single.new arg_specs[0..-2], block_spec, arg_specs[-1]
    end

    def read_arg_spec!
      spec = read_simple_arg_spec!

      skip_spaces

      if check /\|\|/
        return spec
      end

      if match /\.\.\./
        spec = Validator::Array.new(spec)
      end

      skip_spaces
      return spec unless check /\|/

      ret = [spec]
      # TODO: Could be optimize(for more than two elements)
      while match /\|/
        skip_spaces
        ret << read_arg_spec!
        skip_spaces
      end
      return Validator::Or.new(ret)

      raise "Should not reach here: #{current_source_info}"
    end

    def read_simple_arg_spec!
      if match /(::)?[A-Z]\w+(::[A-Z]\w+)*/
        klass = const_get_from ::Kernel, matched.strip
        Validator::Type.for(klass)
      elsif match /\*/
        Validator::Any.instance
      elsif check /->/ or match /--/ or check /\|\|/ or eos?
        Validator::DontCare.instance
      elsif match /\[/
        specs = []
        begin
          skip_spaces
          break if check /\]/
          specs << read_arg_spec!
          skip_spaces
        end while match /,/
        skip_spaces
        match /\]/ || (raise error_message :array_end)
        Validator::ArrayAsStruct.new(specs)
      elsif match /{/
        entries = []
        begin
          skip_spaces
          break if check /}/
          entries << read_hash_entry!
          skip_spaces
        end while match /,/
        match /}/ || (raise error_message :hash_end)
        Validator::Hash.new(entries)
      elsif match /nil/
        Validator::Nil.instance
      else
        raise error_message :arg_spec
      end
    end

    def read_block_spec
      if match /&\?/
        Validator::Or.new([
          Validator::Type.for(Proc),
          Validator::Nil.instance,
        ])
      elsif match /&/
        Validator::Type.for(Proc)
      else
        nil
      end
    end

    def read_hash_entry!
      key = read_hash_key!
      skip_spaces
      match /:/ || (raise error_message :hash_colon)
      skip_spaces
      spec = read_arg_spec!

      [key, spec]
    end

    def read_hash_key!
      if match /[a-zA-Z]\w*[?!]?/
        matched.to_sym
      elsif match /['"]/
        terminator = matched
        if match /([^\\#{terminator}]|\\.)*#{terminator}/
          matched[0..-2]
        else
          raise error_message :hash_key_string
        end
      else
        raise error_message :hash_key
      end
    end

    def read_arrow
      match /->/
    end

    def read_arrow!
      read_arrow || (raise error_message :arrow)
    end

    def error_message expected
      "parse error(expected: #{expected}) #{current_source_info}"
    end

    def current_source_info
      "src = #{@src.string.inspect}, error at: \"#{@src.string[@src.pos..(@src.pos+30)]}\""
    end

    def const_get_from root, name
      name.gsub(/^::/,'').split(/::/).inject(root) do|root, name|
        root.const_get(name.to_sym)
      end
    rescue NameError => e
      raise NameError, "NameError: #{name.inspect}"
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

        # TODO this process do same validate twice. fix it for performance.
        spec.call_with_validate(method, *args, &block)
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
          spec.validate_argument! arg
        end
      end

      def validate_block(block)
        raise Typedocs::BlockError, "Cant accept block" if !block_spec && block
        if block_spec
          block_spec.validate_block! block
        end
      end

      def validate_retval(ret)
        retval_spec.validate_retval! ret
      end
    end
  end

  class Validator
    def validate_argument!(obj)
      raise Typedocs::ArgumentError, "Bad value: #{obj.inspect}" unless valid? obj
    end

    def validate_retval!(obj)
      raise Typedocs::RetValError, "Bad value: #{obj.inspect}" unless valid? obj
    end

    def validate_block!(obj)
      raise Typedocs::BlockError, "Bad block: #{obj.inspect}" unless valid? obj
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

    class Nil < Validator
      def self.instance
        @instance ||= new
      end
      def valid?(obj)
        obj.nil?
      end
    end

    class ArrayAsStruct < Validator
      def initialize(specs)
        @specs = specs
      end

      def valid?(obj)
        obj.is_a?(::Array) &&
        @specs.size == obj.size &&
        @specs.zip(obj).all?{|spec,elm| spec.valid?(elm)}
      end
    end

    class Array < Validator
      def initialize(spec)
        @spec = spec
      end
      def valid?(obj)
          obj.is_a?(::Array) && obj.all?{|elm| @spec.valid?(elm)}
      end
    end

    class Hash < Validator
      # [key, spec]... ->
      def initialize(entries)
        @entries = entries
      end
      def valid?(obj)
        obj.is_a?(::Hash) &&
        @entries.size == obj.size &&
        @entries.all? {|key, spec| obj.has_key?(key) && spec.valid?(obj[key]) }
      end
    end

    class Or < Validator
      def initialize(children)
        @children = children
      end
      def valid?(obj)
        @children.any?{|spec| spec.valid? obj}
      end
    end
  end

  module ClassMethods
  end

  class ArgumentError < ::ArgumentError; end
  class RetValError < ::StandardError; end
  class BlockError < ::StandardError; end
end
