begin
  require 'typedocs'
rescue LoadError
  require 'typedocs/fallback/impl'
  Typedocs = TypedocsFallback
end
