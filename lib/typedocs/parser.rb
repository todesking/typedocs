class Typedocs::Parser; end

require 'typedocs/parser/ast_builder'
require 'typedocs/parser/object_builder'

class Typedocs::Parser
  def parse(klass, src, type = :root)
    ast = Typedocs::Parser::ASTBuilder.new
    obj = Typedocs::Parser::ObjectBuilder.create_builder_for(klass)

    root = ast.public_send(type)

    result =
      begin
        ast = root.parse(src)
        case type
        when :root
          obj.create_method_spec ast
        when :type
          obj.create_unnamed_type ast
        else
          raise "Invalid type: #{type.inspect}"
        end
      rescue Parslet::ParseFailed => e
        raise e.cause.ascii_tree
      rescue ArgumentError => e
        error = StandardError.new("Parse error: Maybe parser's bug. Input=#{src.inspect}, Error = #{e}")
        error.set_backtrace e.backtrace
        raise error
      end
    if result.is_a?(Hash)
      raise "Parse error: Maybe parser's bug or unexpected argument(type: #{type.inspect}). Input=#{src.inspect}, Result=#{result.inspect}"
    end
    result
  end
end
