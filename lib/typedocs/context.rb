class Typedocs::Context
  def self.valid_udt_name?(name)
    /\A@[A-Z][a-zA-Z0-9]*\Z/ =~ name.to_s
  end

  def initialize(klass)
    @klass = klass
    # udt_name => spec
    @specs = {}
  end
  def typedef(name, definition)
    raise ArgumentError, "Invalid user-defined type name: #{name}" unless self.class.valid_udt_name?(name)
    @specs[name.to_s] = Typedocs::Parser.new(@klass, definition).parse(:type)
  end
  def defined_type!(name)
    self_defined_type(name) || outer_defined_type(name) || (raise Typedocs::NoSuchType, "Type not found in #{@klass.name}: #{name}")
  end
  def defined_type(name)
    self_defined_type(name) || outer_defined_type(name) || parent_defined_type(name)
  end
  def self_defined_type(name)
    @specs[name]
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
