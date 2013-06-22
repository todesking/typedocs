class Typedocs::Context
  def initialize(klass)
    @klass = klass
    @types = {}
  end
  def typedef(name, definition)
    raise ArgumentError, "Invalid user-defined type name: #{name}" unless /\A@[A-Z][a-zA-Z0-9]*\Z/ =~ name.to_s
    @types[name.to_s] = Typedocs::ArgumentSpec::UserDefinedType.new(@klass, name, definition)
  end
  def defined_type(name)
    @types[name] || (raise ArgumentError, "Not found: #{name} in #{@klass}")
  end
end
