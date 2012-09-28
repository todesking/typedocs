require 'strscan'

require "typedocs/version"

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
      @typedocs_current_def = nil

      if Typedocs::DSL.enabled?
        class << klass
          def tdoc!(doc_str)
            @typedocs_current_def = ::Typedocs::DSL.parse self, doc_str
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

    def self.parse klass, doc
      Typedocs::Parser.new(klass, doc).parse
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
    def initialize klass, src
      @klass = klass
      @src = StringScanner.new(src)
    end

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
      # Currently, name is accepted but unused
      name = read_arg_spec_name

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

    def read_arg_spec_name
      if match /[A-Za-z_0-9]+:/
        matched.gsub(/:$/,'')
      else
        nil
      end
    end

    def read_simple_arg_spec!
      if match /(::)?[A-Z]\w*(::[A-Z]\w*)*/
        Validator::Type.new(@klass, matched.strip)
      elsif match /_/
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
        skip_spaces
        entries = []
        if check /['":]/
          ret = read_hash_value!
        elsif check /}/
          ret = Validator::HashValue.new([])
        else
          ret = read_hash_type!
        end
        match /}/ || (raise error_message :hash_end)
        ret
      elsif match /nil/
        Validator::Nil.instance
      else
        raise error_message :arg_spec
      end
    end

    def read_block_spec
      if match /&\?/
        Validator::Or.new([
          Validator::Type.new(@klass, '::Proc'),
          Validator::Nil.instance,
        ])
      elsif match /&/
        Validator::Type.new(@klass, '::Proc')
      else
        nil
      end
    end

    def read_hash_type!
      skip_spaces
      key_spec = read_arg_spec!
      skip_spaces
      match /\=>/ or (raise error_message :hash_arrorw)
      skip_spaces
      value_spec = read_arg_spec!
      Validator::HashType.new(key_spec, value_spec)
    end

    def read_hash_value!
      entries = []
      begin
        skip_spaces
        break if check /}/
        entries << read_hash_entry!
        skip_spaces
      end while match /,/
      Validator::HashValue.new(entries)
    end

    def read_hash_entry!
      key = read_hash_key!
      skip_spaces
      match /\=>/ || (raise error_message :hash_colon)
      skip_spaces
      spec = read_arg_spec!

      [key, spec]
    end

    def read_hash_key!
      if match /:[a-zA-Z]\w*[?!]?/
        matched.gsub(/^:/,'').to_sym
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
      raise Typedocs::ArgumentError, "Expected #{description} but #{inspect_value obj}" unless valid? obj
    end

    def validate_retval!(obj)
      raise Typedocs::RetValError, "Expected #{description} but #{inspect_value obj}" unless valid? obj
    end

    def validate_block!(obj)
      raise Typedocs::BlockError, "Bad value: #{obj.inspect}" unless valid? obj
    end

    def inspect_value(obj)
      "#{obj.class.name}: #{obj.inspect}"
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
      def description
        '--(dont care)'
      end
    end

    class Any < Validator
      def self.instance
        @instance ||= new
      end
      def valid?(obj)
        true
      end
      def description
        'any objects'
      end
    end

    class Type < Validator
      def initialize(klass, name)
        @klass = klass
        @name = name
      end

      def target_klass
        @target_klass ||= find_const @klass, @name
      end

      def valid?(obj)
        obj.is_a? target_klass
      end

      def description
        "is_a #{target_klass.name}"
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

    class Nil < Validator
      def self.instance
        @instance ||= new
      end
      def valid?(obj)
        obj.nil?
      end
      def description
        nil
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

      def description
        "[#{@specs.map(&:description).join(', ')}]"
      end
    end

    class Array < Validator
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

    class HashValue < Validator
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
        "{#{@entries.map{|key,value| "#{key.inspect}: #{values.description}"}.join(',')}}"
      end
    end
    
    class HashType < Validator
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

    class Or < Validator
      def initialize(children)
        @children = children
      end
      def valid?(obj)
        @children.any?{|spec| spec.valid? obj}
      end
      def description
        "#{@children.map(&:description).join(' | ')}"
      end
    end
  end

  class ArgumentError < ::ArgumentError; end
  class RetValError < ::StandardError; end
  class BlockError < ::StandardError; end
end
