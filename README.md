# Typedocs : Human/Machine readable method specifications

The goal of the project is to provide user-friendly type annotations for Ruby.

NOTICE: This gem is very veta, any APIs/syntaxes may change in future.

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

  tdoc "Numeric -> Numeric"
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

  tdoc "This text is ignored when Typedocs disabled"
end
```

### Grammer

Use `typedocs grammer` command for generate list of grammer.

```
         METHOD_SPEC <- SPACES (METHOD_SPEC1 ('||' SPACES METHOD_SPEC1){0, })
              SPACES <- \\s{0, }
        METHOD_SPEC1 <- ((ARG_SPEC '->' SPACES){0, }) ((BLOCK_SPEC '->' SPACES)?) (RETURN_SPEC?)
            ARG_SPEC <- (ARG_ATTR?) NAMED_TYPE
            ARG_ATTR <- [*?]
          NAMED_TYPE <- TYPE / ARG_NAME ((':' SPACES TYPE)?)
                TYPE <- TYPE1 ('|' SPACES !('|' SPACES) TYPE1){0, }
               TYPE1 <- TYPE_NAME / DEFINED_TYPE_NAME / ANY / VOID / ARRAY / TUPLE / HASHES / VALUES
           TYPE_NAME <- '::'? ([A-Z] [A-Za-z0-9_]{0, } ('::' [A-Z] [A-Za-z0-9_]{0, }){0, }) SPACES
   DEFINED_TYPE_NAME <- '@' TYPE_NAME
                 ANY <- '_' SPACES
                VOID <- 'void' SPACES / '--' SPACES
               ARRAY <- '[' SPACES NAMED_TYPE '...' SPACES ']' SPACES
               TUPLE <- '[' SPACES ((NAMED_TYPE (',' SPACES NAMED_TYPE){0, }){0, }) ']' SPACES
              HASHES <- HASH_V / HASH_T
              HASH_V <- '{' SPACES (HASH_V_ENTRY (',' SPACES HASH_V_ENTRY){0, }) ((',' SPACES '...' SPACES)?) '}' SPACES
        HASH_V_ENTRY <- VALUES '=>' SPACES NAMED_TYPE
              VALUES <- NIL_VALUE / STRING_VALUE / SYMBOL_VALUE
           NIL_VALUE <- 'nil' SPACES
        STRING_VALUE <- STRING_VALUE_SQ / STRING_VALUE_DQ
     STRING_VALUE_SQ <- ''' SPACES (([^'] / '\''){0, }) ''' SPACES
     STRING_VALUE_DQ <- '"' SPACES (([^\"] / '\"'){0, }) '"' SPACES
        SYMBOL_VALUE <- ':' ([A-Za-z_] [A-Za-z0-9_]{0, } [?!]?) SPACES
              HASH_T <- '{' SPACES NAMED_TYPE '=>' SPACES NAMED_TYPE '}' SPACES
            ARG_NAME <- ([_a-z0-9?!]{1, }) SPACES
          BLOCK_SPEC <- (('?' SPACES)?) '&' SPACES (ARG_NAME?)
         RETURN_SPEC <- NAMED_TYPE
```

### Fallbacks

```
# in your gem dir
$ typedocs install-fallback lib
```

and

```ruby
require 'typedocs/fallback' # instead of `require 'typedocs'`

class A
  include Typedocs::DSL
  # ...
end
```

With that, your library works without typedocs dependency.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## TODO

    Method spec definitions:
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
    Enable/Disable for specific class
    get typedoc from method
    Name to complex data structure
    Self hosting
    Re-define existing method's spec
    Auto spec inference(from argument name)
    define from outer
    attr_accessor


* * * * *


    vim: set shiftwidth=2 expandtab:
