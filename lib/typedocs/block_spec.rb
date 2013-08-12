module Typedocs
  class BlockSpec
    def initialize(type, name)
      raise ArgumentError unless [:req, :opt, :none].include?(type)
      @name = name
      @type = type
    end
    attr_reader :name
    def valid?(block)
      case block
      when nil
        return @type == :opt || @type == :none
      when Proc
        return @type == :opt || @type == :req
      else
        raise 'maybe typedocs bug'
      end
    end
    def error_message_for(block)
      raise ArgumentError if valid?(block)
      case @type
      when :req
        "Block not given"
      when :none
        "Block not allowed"
      else
        raise 'maybe typedocs bug'
      end
    end
    def to_source
      n = name
      case @type
      when :req
        "&#{n}"
      when :opt
        "?&#{n}"
      when :none
        ''
      else
        raise "Invalid type: #{@type}"
      end
    end
    def to_source_with_arrow
      if @type == :none
        ''
      else
        "#{to_source} -> "
      end
    end
  end
end
