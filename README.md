# Typedocs : Human/Machine readable method specifications

The goal of the project is to provide user-friendly type annotations for Ruby.

## Platform

Ruby 1.9

## Installation

Add this line to your application's Gemfile:

    gem 'typedocs'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install typedocs

## Usage

### Method type annotations

Some of features is not implemented.

```ruby
class X
  include Typedocs::DSL

  tdoc!"Numeric -> Numeric"
  def square x
    x * x
  end
end

X.new.square 10
# => 100

X.new.square '100'
# Typedocs::TypeMissmatch: Argument x is not Numeric('100')

Typedocs::DSL.do_nothing
class X
  include Typedocs::DSL

  tdoc!"This text is ignored when Typedocs disabled"
end
```

### Grammer

    method_spec        = method_spec_single ('||' method_spec_single)*
    method_spec_single = (arg_spec '->')* (block_spec '->')? retval_spec
    retval_spec        = arg_spec
    arg_spec           = or | simple_arg_spec
    simple_arg_spec    = type |  array | array_as_struct | any | hash | dont_care
    block_spec         = '&' | '&?'
    type               = Class or Module name
    or                 = simple_arg_spec '|' simple_arg_spec
    array              = arg_spec...
    array_as_struct    = '[' arg_spec (',' arg_spec)* ']'
    hash               = '{' hash_element (',' hash_element)* '}'
    hash_element       = hash_key ':' arg_spec
    hash_key           = 'String' | "String" | Symbol
    any                = '*'
    dont_care          = '' | '--'

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## TODO

    Method spec definitions:
      tdoc!"Integer -> Integer"
      def default_value i=10

    Basic validations:
      name:spec style
      Validate name:spec style when name should refer argument name
      Block type specification
      Values
        Integer(>0)
        String(not .empty?)
      Named specs
        @positive_int
      Duck typing(callable etc)
    foo 1,2,skip_validation('3')
    Ignore checking for specific argument
    Exception spec
    Class methods
    Informative error message
    Method override
    Singleton method
    Self hosting
    Re-define existing method's spec
    Auto spec inference(from argument name)


* * * * *


    vim: set shiftwidth=2 expandtab:
