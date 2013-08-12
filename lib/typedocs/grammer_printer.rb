module Typedocs::GrammerPrinter
  def self.print_grammer(out)
    parser = Typedocs::Parser::ASTBuilder.new
    print_recursive(out, parser.root)
  end

  def self.print_recursive(out, root)
    waiting = [root]
    ignore = {}

    until waiting.empty?
      entity = waiting.pop
      next if ignore[entity]
      ignore[entity] = true

      if entity.kind_of?(Parslet::Atoms::Entity)
        out.puts "#{'%20s' % entity.to_s} <- #{entity.parslet.to_s.gsub(/[a-z_]+:/, '')}"
      end

      atoms = Parslet::Atoms

      case entity
      when atoms::Sequence
        entity.parslets.reverse.each do|pl|
          waiting.push pl
        end
      when atoms::Lookahead
        waiting.push entity.bound_parslet
      when atoms::Repetition
        waiting.push entity.parslet
      when atoms::Alternative
        entity.alternatives.reverse.each do|pl|
          waiting.push pl
        end
      when atoms::Entity
        waiting.push entity.parslet
      when atoms::Named
        waiting.push entity.parslet
      when atoms::Re, atoms::Str
      else
        raise "Unsupported class: #{entity.class}"
      end
    end
  end
end
