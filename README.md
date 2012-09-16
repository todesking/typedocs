# Typedocs : Human/Machine readable method specifications

The goal of the project is to provide user-friendly type annotations for Ruby.

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

    class X
      include Typedocs::DSL

      tdoc!"Numeric -> Numeric"
      def self.square x
        x * x
      end
    end

    X.square 10
    # => 100

    X.square '100'
    # Typedocs::TypeMissmatch: Argument x is not Numeric('100')

    Typedocs::DSL.do_nothing
    class X
      include Typedocs::DSL

      tdoc!"This text is ignored when Typedocs disabled"
    end

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## TODO

    Method spec definitions:
      foo(arg1, arrg2 = default_value)
      foo(arg1, *rest)
      foo(arg1, &block)
      foo() # but block needed
      foo(*args) # many valid patterns
    Basic validations:
      name:spec style
      Validate name:spec style when name should refer argument name
      Types
        Hash
      Values
        Integer(>0)
        String(not .empty?)
      Named specs
        @positive_int
    Informative error message
    Method override
    Disable checking


* * * * *


    vim: set shiftwidth=2 expandtab:
