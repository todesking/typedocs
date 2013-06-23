require 'spec_helper'

describe 'Typedocs.typedef' do
  before(:each) do
    @ns = Module.new
    ::TypedocsSpecSandbox = @ns
  end
  after(:each) do
    Object.instance_eval { remove_const :TypedocsSpecSandbox }
    Typedocs.initialize!
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
      it 'should referable from inner type' do
        expect {
          class @ns::B
            include Typedocs::DSL
            tdoc "@ConfigHash"
            def illegal; {}; end
          end
        }.to raise_error Typedocs::NoSuchType
      end
      it 'should not referable from other type' do
        class klass::InnerType
          include Typedocs::DSL
          tdoc "@ConfigHash"
          def illegal; {}; end
        end
        expect { klass::InnerType.new.illegal }.to raise_error Typedocs::RetValError
      end
      it 'should not referable from inherited type' do
        expect {
          class @ns::C < klass
            include Typedocs::DSL
            tdoc "@ConfigHash"
            def illegal; {}; end
          end
        }.to raise_error Typedocs::NoSuchType
      end
    end
  end
end
