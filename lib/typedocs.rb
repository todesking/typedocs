require 'strscan'

module Typedocs; end

require "typedocs/version"
require "typedocs/dsl"
require "typedocs/parser"
require "typedocs/argument_spec"
require "typedocs/arguments_spec"
require "typedocs/block_spec"
require "typedocs/method_spec"
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
