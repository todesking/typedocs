# Typedocs : Human/Machine readable method specifications

The goal of the project is to provide user-friendly type annotations for Ruby.

NOTICE: This gem is very veta, any APIs/syntaxes may change in future.

## Platform

Ruby 1.9/2.0

## Usage

### Method type annotations with dynamic type checking

```ruby
require 'typedocs/enable' # Enable dynamic type-checking

require 'typedocs'
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
```

By default, `require 'typedocs'` define some do-nothing methods.
For dynamic type-checking, `require 'typedocs/enable'` bereore `require 'typedocs'`.
For example: `ruby -rtypedocs/enable ./foo.rb`, or require it in `spec_helper.rb`, etc.

### Example
```ruby
class Example
  include Typedocs::DSL

  tdoc "String"
  def to_s; end

  tdoc "Integer -> String|nil"
  def [](index); end

  tdoc "& -> Array || Enumerable"
  def map; end

  tdoc "[[key:Integer, value:String]...]"
  def to_a; end

  tdoc "title:String -> url:String|Hash -> ?options:Hash -> String ||
        url:String|Hash -> ?options:Hash -> &content -> String"
  def link_to(*args); end
end
```

### User Defined Types

```ruby
class SomethingBuilder
  include Typedocs
  tdoc.typedef "@ConfigHash", "{:attr_1 => Integer, :attr_2 => String}"

  tdoc "@ConfigHash -> Something"
  def build(config); end

  tdoc "@ConfigHash -> SomeContext -> Something"
  def build_with_context(config, context); end
end
```

### Features

```
syntax: arg1_name:Type1 -> arg2_name:Type2 -> &block -> ResultType

# Type name
TypeName

# User defined type name
@TypeName

# Exact value(symbol, string)
:a
'a'
"a"

# Special matchers
_     # Any object
void  # The value is not used. Typically for return type.
      # If return type is omitted, treated as void.

# Data structure
[Type...]   # Array of Type
[T1, T2]    # Fixed number array(tuple)
{K => V}    # Hash specified by key type and value type
{:key1 => V1, "key2" => V2}
            # Hash specified by possible key value and value type
{:key1 => V1, "Key2" => V2, ...}
            # Same as above, but may contains unspecified key-value pair

# Selection
A|B  # A or B

# Qualifier
*var_arg
?optional_arg

&block
?&optional_block
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
When typedocs gem not found, `tdoc` method do nothing.

## Installation

Add this line to your application's Gemfile:

    gem 'typedocs'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install typedocs

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
