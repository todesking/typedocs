class Typedocs::Context
  def initialize(klass)
    @klass = klass
    @types = {}
  end
  def typedef(name, definition)
    raise ArgumentError, "Invalid user-defined type name: #{name}" unless /\A@[A-Z][a-zA-Z0-9]*\Z/ =~ name.to_s
    @types[name.to_s] = Typedocs::ArgumentSpec::UserDefinedType.new(@klass, name, definition)
  end
  def defined_type!(name)
    self_defined_type(name) || outer_defined_type(name) || (raise Typedocs::NoSuchType, "Type not found in #{@klass.name}: #{name}")
  end
  def defined_type(name)
    self_defined_type(name) || outer_defined_type(name) || parent_defined_type(name)
  end
  def self_defined_type(name)
    @types[name]
  end
  def outer_defined_type(name)
    return nil unless @klass.name
    outer_name = @klass.name.split(/::/)[0..-2]
    unless outer_name.empty?
      outer_klass = outer_name.inject(::Object) {|ns, name| ns.const_get(name) }
      Typedocs.context(outer_klass).defined_type(name)
    end
  end
  def parent_defined_type(name)
    return nil unless @kass.kind_of? ::Class
    superclass = @klass.superclass
    return nil unless superclass
    Typedocs.context(superclass).defined_type(name)
  end
end
