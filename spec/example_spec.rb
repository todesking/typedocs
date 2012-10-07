load File.join(File.dirname(__FILE__), 'spec_helper.rb')

describe 'Usage examples' do
  describe 'Simple example' do
    class SimpleExample
      include Typedocs::DSL

      tdoc "Numeric -> Numeric"
      def square x
        x * x
      end
    end

    subject { SimpleExample.new }
    it { subject.square(10).should == 100 }
    it { expect { subject.square('10') }.to raise_error Typedocs::ArgumentError }
  end
  describe 'Basic usage' do
    class BasicUsage
      include Typedocs::DSL

      tdoc "Numeric -> Numeric"
      def square(x)
        x * x
      end

      tdoc "String"
      def expected_string_but_nil
        nil
      end

      tdoc "Numeric -> [Integer,String]"
      def return_pair(num)
        [num.to_i, num.to_s]
      end

      tdoc "[]"
      def return_empty_array
        []
      end

      tdoc "_ -> String | Integer"
      def return_int_or_string(is_str)
        is_str ? 'string' : 100
      end

      tdoc "nil"
      def return_nil
        nil
      end
    end

    describe BasicUsage do
      subject { BasicUsage.new }
      it do
        subject.square(10).should == 100
      end
      it do
        expect { subject.square('10') }.to raise_error Typedocs::ArgumentError
      end
      it do
        expect { subject.expected_string_but_nil }.to raise_error Typedocs::RetValError
      end
      it do
        subject.return_pair(1).should == [1, '1']
      end

      it do
        subject.return_empty_array.should == []
      end

      it do
        subject.return_int_or_string(true).should == 'string'
        subject.return_int_or_string(false).should == 100
      end
      it do
        subject.return_nil.should == nil
      end
    end
  end
  describe 'Disable typedocs' do
    Typedocs::DSL.do_nothing
    class Unchecked
      include Typedocs::DSL
      tdoc "Integer"
      def not_integer
        nil
      end
    end
    Typedocs::DSL.do_anything

    describe do
      it do
        Unchecked.new.not_integer.should == nil
      end
    end
  end
  class Initialize
    include Typedocs::DSL

    tdoc "Integer ->"
    def initialize(n)
    end
  end
  describe Initialize do
    it do
      Initialize.new(1)
    end
    it do
      expect { Initialize.new(nil) }.to raise_error Typedocs::ArgumentError
    end
  end

  class ClassMethods
    include Typedocs::DSL

    tdoc "String->Integer"
    def self.class_method(s); s.to_i; end

    def untyped_instance_method(arg); arg; end
  end
  describe ClassMethods do
    it do
      ClassMethods.new.untyped_instance_method(1).should == 1
    end
    it do
      expect { ClassMethods.class_method(1) }.to raise_error Typedocs::ArgumentError
    end
  end

  class RelativeTypeNames
    class Outer
      include Typedocs::DSL

      tdoc "A"
      def self.a; A.new; end
    end
    class A; end
  end
  describe RelativeTypeNames do
    it do
      RelativeTypeNames::Outer.a.should be_is_a(RelativeTypeNames::A)
    end
  end

end

