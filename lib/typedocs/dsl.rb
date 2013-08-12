module Typedocs::DSL
  def self.included(klass)
    # doc:String | special:(:inherit) | nil
    @typedocs_current_def = nil

    class << klass
      def tdoc(*args)
        if args.size == 1 && args[0].is_a?(String) || args[0].is_a?(Symbol)
          @typedocs_current_def = args[0]
        elsif args.size == 0
          Typedocs::MultiFunctionalInterface.new(self)
        else
          raise ArgumentError
        end
      end

      def method_added(name)
        super
        return unless @typedocs_current_def

        method_spec = ::Typedocs.create_method_spec(self, name, @typedocs_current_def)
        @typedocs_current_def = nil

        ::Typedocs.define_spec self, name, method_spec
      end

      def singleton_method_added(name)
        super
        return unless @typedocs_current_def

        method_spec = ::Typedocs.create_method_spec(self, name, @typedocs_current_def)
        @typedocs_current_def = nil

        singleton_class = class << self; self; end
        ::Typedocs.define_spec singleton_class, name, method_spec
      end
    end
  end
end
