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


    Typedocs.check_nothing
    X.square '100'
    # TypeError: can't convert String into Integer

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
    Basic validations:
      Types
        is_a
        *(any)
        Arry([])
        Array shorthand(...)
        Hash
        --(Dont care)
      Values
        Integer(>0)
        String(not .empty?)
      Named specs
        @positive_int
      
    Method override


* * * * *


    vim: set shiftwidth=2 expandtab:
