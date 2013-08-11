class Typedocs::Parser; end

require 'typedocs/argument_spec'
require 'parslet'

class Typedocs::Parser::ObjectBuilder < Parslet::Transform
  VAL = {value: simple(:val)}

  rule(type_name: VAL) { "type_name:#{val}" }
end
