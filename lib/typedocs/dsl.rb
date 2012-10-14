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
    # doc:String | special:(:inherit) | nil
    @typedocs_current_def = nil

    if Typedocs::DSL.enabled?
      class << klass
        def tdoc(arg)
          @typedocs_current_def = arg
        end

        def method_added(name)
          super
          return unless @typedocs_current_def

          method_spec = ::Typedocs::DSL.method_spec(self, name, @typedocs_current_def)
          @typedocs_current_def = nil

          ::Typedocs.define_spec self, name, method_spec
        end

        def singleton_method_added(name)
          super
          return unless @typedocs_current_def

          method_spec = ::Typedocs::DSL.method_spec(self, name, @typedocs_current_def)
          @typedocs_current_def = nil

          singleton_class = class << self; self; end
          ::Typedocs.define_spec singleton_class, name, method_spec
        end
      end
    else
      class << klass
        def tdoc(doc_str); end
      end
    end
  end

  def self.method_spec(klass, name, tdoc_arg)
    case tdoc_arg
    when String
      Typedocs::Parser.new(klass, tdoc_arg).parse
    when :inherit
      Typedocs.super_method_spec(klass, name) || (raise "can't find typedoc for super method: #{klass}##{name}")
    else
      raise "Unsupported document: #{tdoc_arg.inspect}"
    end
  end
end
