# -*- coding:utf-8 -*-

class Typedocs::MultiFunctionalInterface
  def initialize(klass)
    @klass = klass
  end
  def typedef(typename, definition)
    Typedocs.context(@klass).typedef(typename, definition)
  end
end
