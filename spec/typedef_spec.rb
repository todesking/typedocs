require 'spec_helper'

describe 'Typedocs.typedef' do
  before(:each) do
    @ns = Module.new
    ::TypedocsSpecSandbox = @ns
  end
  after(:each) do
    Object.instance_eval { remove_const :TypedocsSpecSandbox }
  end
  describe 'spec itself' do
    it('Object::TypeDocsSpecSandBox exists') do
      ::TypedocsSpecSandbox.should_not be_nil
      ::TypedocsSpecSandbox.name.should == 'TypedocsSpecSandbox'
    end
  end

  describe 'basic usage' do
    before(:each) do
      class @ns::A
        include Typedocs::DSL
      end
    end
    let(:klass) { @ns::A }
    describe 'defining custom type @ConfigHash' do
      before(:each) do
        klass.class_eval do
          tdoc.typedef :@ConfigHash, "{:hoge => Integer}"
        end
      end
      it 'should referable from definede class' do
        klass.class_eval {
          tdoc "@ConfigHash"
          def legal
            {hoge: 10}
          end
          tdoc "@ConfigHash"
          def illegal
            {hoge: 'hoge'}
          end
        }
        klass.new.legal.should == {hoge: 10}
        expect { klass.new.illegal }.to raise_error Typedocs::RetValError
      end
    end
  end
end
