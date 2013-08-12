# Ruby argument pattern:
# - required* optional* (rest requied*)?
# - optional+ requied* # optional is matched forward-wise
#
# s1 +-opt-> s2 +--req--> s3
#    |          |
#    +----------+---------+--rest--> s6 -req-> s7
#    |         /         /
#    `-req-> s4 -opt-> s5
class Typedocs::ArgumentsSpec
  def initialize
    # [[type, [spec ...]] ...]
    @specs = []
    @current = nil
  end
  def empty?
    @specs.empty?
  end
  def valid?(args)
    matched = match(args)
    matched && matched.all? {|arg, spec| spec.valid? arg}
  end
  def error_message_for(args)
    matched = match(args)
    errors = matched.select{|arg, spec|!spec.valid?(arg)}
    "Expected: #{description}. Errors: #{errors.map{|arg,spec|spec.error_message_for(arg)}.join(' ||| ')}"
  end
  def description
    @specs.flat_map{|t,s|
      attr =
        case t
        when :req
          ''
        when :opt
          '?'
        when :res
          '*'
        else
          raise
        end
      s.map{|spec| "#{attr}#{spec.description}" }
    }.join(' -> ')
  end
  def add_required(arg_spec)
    _add :req, arg_spec
  end
  def add_optional(arg_spec)
    _add :opt, arg_spec
  end
  def add_rest(arg_spec)
    _add :res, arg_spec
  end
  private
  # args:[...] -> success:[[arg,spec]...] | fail:nil
  def match(args)
    args = args.dup
    types = @specs.map{|t,s|t}
    case types
    when [:opt, :req]
      opt, req = @specs.map{|t,s|s}
      return nil unless (req.length..(req.length+opt.length)) === args.size
      args[0...-req.length].zip(opt).to_a + req.zip(args[-req.length..-1]).to_a
    else
      # [reqs, opts, rest, reqs]
      partial = []
      i = 0
      if types[i] == :req
        partial.push @specs[i][1]
        i += 1
      else
        partial.push []
      end
      if types[i] == :opt
        partial.push @specs[i][1]
        i += 1
      else
        partial.push []
      end
      if types[i] == :res
        partial.push @specs[i][1]
        i += 1
      else
        partial.push []
      end
      if types[i] == :req
        partial.push @specs[i][1]
        i += 1
      else
        partial.push []
      end
      return nil unless i == types.length
      reqs, opts, rest, reqs2 = partial
      raise unless rest.length < 2

      len_min = reqs.length + reqs2.length
      if rest.empty?
        len_max = reqs.length + opts.length + reqs2.length
        return nil unless (len_min..len_max) === args.length
      else
        return nil unless len_min <= args.length
      end
      reqs_args = args.shift(reqs.length)
      reqs2_args = args.pop(reqs2.length)
      opts_args = args.shift([opts.length, args.length].min)
      rest_args = args

      rest_spec = rest[0]
      return [
        *reqs_args.zip(reqs),
        *opts_args.zip(opts),
        *(rest_spec ? rest_args.map{|a|[a, rest_spec]} : []),
        *reqs2_args.zip(reqs2),
      ]
    end
  end
  def _add(type,spec)
    Typedocs.ensure_klass(spec, Typedocs::ArgumentSpec)
    if @current == type
      @specs.last[1].push spec
    else
      @specs.push [type, [spec]]
      @current = type
    end
  end
end

