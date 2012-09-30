# vim: filetype=ruby
require 'simplecov-vim/formatter'
class SimpleCov::Formatter::MergedFormatter
  def format(result)
    SimpleCov::Formatter::HTMLFormatter.new.format(result)
    SimpleCov::Formatter::VimFormatter.new.format(result)
  end
end
SimpleCov.start do
  formatter SimpleCov::Formatter::MergedFormatter
end
