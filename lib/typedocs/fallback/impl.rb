module TypedocsFallback
  def self.method_missing(name, *args)
    nil
  end

  NULL_OBJECT = BasicObject.new
  def NULL_OBJECT.method_missing(name, *args)
    self
  end

  module DSL
    def self.included(klass)
      def klass.tdoc(*args)
        NULL_OBJECT
      end
    end
  end
end

