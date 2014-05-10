describe Typedocs::Parser do
  subject { Typedocs::Parser.new }
  def td(type, src, expected)
    subject.parse(nil, src, type).to_source.should == expected
  end
  it { td(:root, 'A|B', 'A|B') }
  it { td(:root, 'name:String', 'name:String') }
  it { td(:root, 'a -> b', 'a:_ -> b:_') }
  it { td(:root, 'x:A->ret:B || a:A -> b:B -> ret:C', 'x:A -> ret:B || a:A -> b:B -> ret:C') }
  it { td(:root, 'x:X -> ?y -> *Z ->', 'x:X -> ?y:_ -> *Z -> void') }
  it { td(:root, 'a -> ?&b ->', 'a:_ -> ?&b -> void') }
  it { td(:type, '@X', '@X') }
  it { td(:type, '_', '_') }
  it { td(:type, ':a', ':a') }
  it { td(:type, '"str"', '"str"') }
  it { td(:type, '[A...]', 'A...') }
  it { td(:type, '[A, B]', '[A, B]') }
  it { td(:type, '{A => B}', '{A => B}') }
end
