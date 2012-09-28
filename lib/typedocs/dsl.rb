module Typedocs::DSL
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
