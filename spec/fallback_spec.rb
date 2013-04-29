require 'typedocs/fallback/impl'

describe TypedocsFallback do
  it { should_not be_enabled }
  it('do_anything should success'){ subject.do_anything }
  it('do_nothing should success'){ subject.do_nothing }
  describe TypedocsFallback::DSL do
    subject do
      c = Class.new
      c.instance_eval { include TypedocsFallback::DSL }
      c
    end
    describe '#tdoc' do
      it 'should accepts any arguments' do
        subject.instance_eval do
          tdoc
          tdoc "String"
          tdoc "1", "aaa"
        end
      end
      it 'should return null object' do
        subject.instance_eval do
          tdoc('aaa').bbb().ccc(10, 20).ddd
        end
      end
    end
  end
end
