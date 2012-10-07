class Typedocs::ArgumentSpec
  def error_message_for(obj)
    "Expected #{self.description}, but #{obj.inspect}"
  end
  class Any < self
    def valid?(arg); true; end
    def description; '_'; end
    def error_message_for(arg)
      raise "This spec accepts ANY value"
    end
  end
  class DontCare < Any
    def description; '--'; end
  end
  class TypeIsA < self
    def initialize(klass, name)
      @klass = klass
      @name = name
    end
    def target_klass
      @target_klass ||= find_const @klass, @name
    end
    def valid?(arg);
      arg.is_a? target_klass
    end
    def description
      @name
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
  class Nil < self
    def initialize
      @value = nil
    end
    def valid?(obj)
      obj == @value
    end
    def description
      @value.inspect
    end
    def error_message_for(obj)
      "#{obj} should == #{@value.inspect}"
    end
  end
  class ArrayAsStruct < self
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
  class Array < self
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
  class HashValue < self
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
      "{#{@entries.map{|key,value| "#{key.inspect} => #{value.description}"}.join(', ')}}"
    end
  end
  class HashType < self
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
  class Or < self
    def initialize(children)
      raise ArgumentError, "Children is empth" if children.empty?
      @children = children
    end
    def valid?(obj)
      @children.any?{|spec| spec.valid? obj}
    end
    def description
      "#{@children.map(&:description).join('|')}"
    end
  end
end
