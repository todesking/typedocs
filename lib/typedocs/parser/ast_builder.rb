require 'parslet'

class Typedocs::Parser::ASTBuilder < Parslet::Parser
  root :method_spec

  rule(:method_spec) { spaces >> rep1(method_spec1, s('||')).as(:method_spec) }
  rule(:method_spec1) { (arg_spec >> s('->')).repeat.as(:arg_specs) >> (block_spec >> s('->')).maybe.as(:block_spec) >> return_spec.maybe.as(:return_spec) }

  rule(:arg_spec) {  type.as(:type) | arg_name.as(:name) >> (s(':') >> type.as(:type)).maybe }
  rule(:arg_name) { v(match['_a-z0-9?!'].repeat(1)) >> spaces }

  rule(:block_spec) { s('?').maybe >> s('&') >> arg_name.maybe }

  rule(:return_spec) { arg_spec }

  rule(:type) { rep1(type1, s('|') >> s('|').absent?) }
  rule(:type1) {
    t(:type_name) | t(:defined_type_name) | t(:any) | t(:void) | t(:array) | t(:tuple) | hashes | values
  }

  rule(:type_name) { v(match['A-Z'] >> match['A-Za-z0-9_'].repeat) >> spaces }
  rule(:defined_type_name) { str('@') >> type_name }

  rule(:any) { s('_') }
  rule(:void) { s('void') }

  rule(:array) { s('[') >> arg_spec >> s(',') >> s('...') >> s(']') }
  rule(:tuple) { s('[') >> rep1(arg_spec, s(',')).as(:types) >> s(']') }

  rule(:hashes) { t(:hash_v) | t(:hash_t) }
  rule(:hash_t) { s('{') >> arg_spec.as(:key_t) >> s('=>') >> arg_spec.as(:val_t) >> s('}') }
  rule(:hash_v) { s('{') >> rep1(hash_v_entry, s(',')).as(:entries) >> (s(',') >> s('...')).maybe.as(:anymore) >> s('}') }
  rule(:hash_v_entry) { values.as(:key_v) >> s("=>") >> arg_spec.as(:val_t) }

  rule(:values) { t(:nil_value) | t(:string_value) | t(:symbol_value) }
  rule(:nil_value) { s('nil') }
  rule(:string_value) { s('"') >> v((match['^"'] | str('\\"')).repeat) >> s('"') }
  rule(:symbol_value) { str(':') >> v(match['A-Za-z_'] >> match['A-Za-z0-9_'].repeat >> match['?!'].maybe) >> spaces }

  rule(:spaces) { match('\\s').repeat }

  private
    def s(string)
      str(string) >> spaces
    end

    def sv(string)
      str(string).as(:value) >> spaces
    end

    def v(rule)
      rule.as(:value)
    end

    def t(rule_name)
      send(rule_name).as(rule_name)
    end

    def rep1(rule, separator)
      rule >> (separator >> rule).repeat
    end
end
