module Typedocs
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
      def initialize(args_spec, block_spec, retval_spec)
        Typedocs.ensure_klass(args_spec, Typedocs::ArgumentsSpec)
        Typedocs.ensure_klass(block_spec, Typedocs::BlockSpec)
        Typedocs.ensure_klass(retval_spec, Typedocs::TypeSpec)
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
end
