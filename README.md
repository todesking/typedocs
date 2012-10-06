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
    arg_spec           = (arg_spec_name ':')? arg_option? simple_arg_spec ('|' simple_arg_spec)*
    arg_option         = '?' | '*' # optional / rest
    simple_arg_spec    = type |  array | array_as_struct | any | hash_value | hash_type | dont_care
    block_spec         = '&' | '&?'
    type               = Class or Module name
    array              = arg_spec...
    array_as_struct    = '[' arg_spec (',' arg_spec)* ']'
    hash_value         = '{' hash_element (',' hash_element)* '}'
    hash_element       = hash_key '=>' arg_spec
    hash_type          = '{' arg_spec '=>' arg_spec '}'
    hash_key           = 'String' | "String" | :Symbol
    any                = '*'
    dont_care          = '' | '--'

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## TODO

    rename tdoc! to tdoc
    Method spec definitions:
      remove empty notation for dont_care
      change array notation: [spec ...]
      hash value accepts unspecified keys: { :key => spec, ...}

    Basic validations:
      Block type specification
      Boolean
      Values
        Integer(>0)
        String(not .empty?)
        Symbol(:a | :b | :c)
      Named specs
        @positive_int
      Duck typing(callable etc)
    Skip checking for specific argument
      foo 1,2,skip_validation('3')
    Exception spec
    Informative error message
    Method override
    Self hosting
    Re-define existing method's spec
    Auto spec inference(from argument name)
    attr_accessor


* * * * *


    vim: set shiftwidth=2 expandtab:
