class Typedocs::Parser
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
      Typedocs::MethodSpec::Any.new(specs)
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

    arg_specs = [Typedocs::Validator::DontCare.instance] if arg_specs.empty?

    return Typedocs::MethodSpec::Single.new arg_specs[0..-2], block_spec, arg_specs[-1]
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
      spec = Typedocs::Validator::Array.new(spec)
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
    return Typedocs::Validator::Or.new(ret)

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
      Typedocs::Validator::Type.new(@klass, matched.strip)
    elsif match /_/
      Typedocs::Validator::Any.instance
    elsif check /->/ or match /--/ or check /\|\|/ or eos?
      Typedocs::Validator::DontCare.instance
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
      Typedocs::Validator::ArrayAsStruct.new(specs)
    elsif match /{/
      skip_spaces
      entries = []
      if check /['":]/
        ret = read_hash_value!
      elsif check /}/
        ret = Typedocs::Validator::HashValue.new([])
      else
        ret = read_hash_type!
      end
      match /}/ || (raise error_message :hash_end)
      ret
    elsif match /nil/
      Typedocs::Validator::Nil.instance
    else
      raise error_message :arg_spec
    end
  end

  def read_block_spec
    if match /&\?/
      Typedocs::Validator::Or.new([
        Typedocs::Validator::Type.new(@klass, '::Proc'),
        Typedocs::Validator::Nil.instance,
      ])
    elsif match /&/
      Typedocs::Validator::Type.new(@klass, '::Proc')
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
    Typedocs::Validator::HashType.new(key_spec, value_spec)
  end

  def read_hash_value!
    entries = []
    begin
      skip_spaces
      break if check /}/
      entries << read_hash_entry!
      skip_spaces
    end while match /,/
    Typedocs::Validator::HashValue.new(entries)
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
