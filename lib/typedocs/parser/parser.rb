require 'parslet'

class Typedocs::Parser::Parser < Parslet::Parser
  root :method_spec

  rule(:method_spec) { spaces >> method_spec1 >> (s('||') >> method_spec1).repeat }
  rule(:method_spec1) { (arg_spec >> s('->')).repeat >> (block_spec >> s('->')).maybe >> return_spec.maybe }

  rule(:arg_spec) {  type | arg_name >> (s(':') >> type).maybe }
  rule(:arg_name) { match['_a-z0-9?!'].repeat(1) >> spaces }

  rule(:block_spec) { s('?').maybe >> s('&') >> arg_name.maybe }

  rule(:return_spec) { arg_spec }

  rule(:type) { (type1 >> s('|') >> s('|').absent?).repeat >> type1 }
  rule(:type1) {
    type_name | defined_type_name | special | array | tuple | hash | value
  }

  rule(:type_name) { match['A-Z'] >> match['A-Za-z0-9_'].repeat >> spaces }
  rule(:defined_type_name) { str('@') >> type_name }

  rule(:special) { any | void }
  rule(:any) { s('_') }
  rule(:void) { s('void') }

  rule(:array) { s('[') >> arg_spec >> s(',') >> s('...') >> s(']') }
  rule(:tuple) { s('[') >> (arg_spec >> s(',')).repeat(1) >> arg_spec >> s(']') }

  rule(:hash) { hash_with_type | hash_with_value }
  rule(:hash_with_type) { s('{') >> arg_spec >> s('=>') >> arg_spec >> s('}') }
  rule(:hash_with_value) { s('{') >> (hash_entry >> s(',')).repeat >> (hash_entry | s('...')) >> s('}') }
  rule(:hash_entry) { (string_value | symbol_value) >> s("=>") >> arg_spec }

  rule(:value) { nil_value | string_value | symbol_value }
  rule(:nil_value) { s('nil') }
  rule(:string_value) { s('"') >> (match['^"'] | str('\\"')).repeat >> s('"') }
  rule(:symbol_value) { str(':') >> match['A-Za-z_'] >> match['A-Za-z0-9_'].repeat >> match['?!'].maybe >> spaces }

  rule(:spaces) { match('\\s').repeat }

  private
    def s(string)
      str(string) >> spaces
    end
end
