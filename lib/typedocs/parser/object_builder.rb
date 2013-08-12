class Typedocs::Parser; end

require 'parslet'
require 'typedocs/argument_spec'

class Typedocs::Parser::ObjectBuilder
  def self.create_builder_for(klass)
    Parslet::Transform.new do
      val = {value: simple(:val)}
      as = Typedocs::ArgumentSpec
      rule(type_name: val) { as::TypeIsA.new(klass, val) }
    end
  end
end
