def parse(str)
  DMark::Parser.new(str).parse
end

def element(name, attributes, children)
  DMark::ElementNode.new(name, attributes, children)
end

describe DMark::Parser::ParserError do
  subject(:error) do
    DMark::Parser.new(content).parse
  rescue described_class => e
    break e
  end

  let(:content) do
    "#p Stuff\n\n#p More stuff }"
  end

  describe '#message' do
    subject { error.message }

    it { is_expected.to eq('parse error at line 3, col 15: unexpected } -- try escaping it as "%}"') }
  end

  describe '#fancy_message' do
    subject { error.fancy_message }

    it { is_expected.to eq("parse error at line 3, col 15: unexpected } -- try escaping it as \"%}\"\n\n#p More stuff }\n\e[31m              ↑\e[0m") }
  end
end

describe 'DMark::Parser#parser' do
  it 'parses' do
    expect(parse('')).to eq []
    expect(parse('#p')).to eq [element('p', {}, [])]
    expect(parse('#p hi')).to eq [element('p', {}, ['hi'])]
    expect(parse('#p hi %%')).to eq [element('p', {}, ['hi ', '%'])]
    expect(parse('#p hi %}')).to eq [element('p', {}, ['hi ', '}'])]
  end

  it 'parses element with name containing dash' do
    expect(parse('#intro-para hi')).to eq [
      element('intro-para', {}, ['hi'])
    ]
  end

  it 'parses element with name containing underscore' do
    expect(parse('#intro_para hi')).to eq [
      element('intro_para', {}, ['hi'])
    ]
  end

  it 'parses element with name containing uppercase letters' do
    expect(parse('#IntroPara hi')).to eq [
      element('IntroPara', {}, ['hi'])
    ]
  end

  it 'does not parse element with name starting with a dash' do
    expect { parse('#-intro hi there') }.to raise_error(DMark::Parser::ParserError)
  end

  it 'does not parse element with name starting with an underscore' do
    expect { parse('#_intro hi there') }.to raise_error(DMark::Parser::ParserError)
  end

  it 'does not parse element with name starting with a digit' do
    expect { parse('#4ever best friends') }.to raise_error(DMark::Parser::ParserError)
  end

  it 'parses escaped % in block' do
    expect(parse('#p %%')).to eq [
      element('p', {}, ['%'])
    ]
  end

  it 'parses escaped } in block' do
    expect(parse('#p %}')).to eq [
      element('p', {}, ['}'])
    ]
  end

  it 'parses escaped % in inline block' do
    expect(parse('#p %foo{%%}')).to eq [
      element(
        'p', {},
        [
          element('foo', {}, ['%'])
        ]
      )
    ]
  end

  it 'parses escaped } in inline block' do
    expect(parse('#p %foo{%}}')).to eq [
      element(
        'p', {},
        [
          element('foo', {}, ['}'])
        ]
      )
    ]
  end

  it 'parses block with text and element content' do
    expect(parse('#p hi %em{ho}')).to eq [
      element(
        'p', {}, [
          'hi ',
          element('em', {}, ['ho'])
        ]
      )
    ]
  end

  it 'parses block with text and element content, followed by newline' do
    expect(parse("#p hi %em{ho}\n")).to eq [
      element(
        'p', {}, [
          'hi ',
          element('em', {}, ['ho'])
        ]
      )
    ]
  end

  it 'parses children' do
    expect(parse("#p hi %em{ho}\n  #p child p")).to eq [
      element(
        'p', {}, [
          'hi ',
          element('em', {}, ['ho']),
          element('p', {}, ['child p'])
        ]
      )
    ]
  end

  it 'parses children multiple levels deep' do
    expect(parse("#p hi %em{ho}\n  #p child p\n    #p subchild p")).to eq [
      element(
        'p', {}, [
          'hi ',
          element('em', {}, ['ho']),
          element(
            'p', {}, [
              'child p',
              element(
                'p', {}, [
                  'subchild p'
                ]
              )
            ]
          )
        ]
      )
    ]
  end

  it 'ignores blanks' do
    expect(parse("#p foo\n \n  #p bar\n  \n\n    #p qux")).to eq [
      element(
        'p', {}, [
          'foo',
          element(
            'p', {}, [
              'bar',
              element(
                'p', {}, [
                  'qux'
                ]
              )
            ]
          )
        ]
      )
    ]
  end

  it 'reads multiple consecutive blocks' do
    expect(parse("#p foo\n#p bar")).to eq [
      element('p', {}, ['foo']),
      element('p', {}, ['bar'])
    ]
  end

  it 'includes raw content' do
    expect(parse("#p foo\n  donkey")).to eq [
      element('p', {}, %W[foo \n donkey])
    ]
  end

  it 'includes raw content including initial indentation' do
    expect(parse("#p foo\n    donkey")).to eq [
      element('p', {}, ['foo', "\n", '  donkey'])
    ]
  end

  it 'includes raw content from multiple lines' do
    expect(parse("#p foo\n    donkey\n  giraffe\n    zebra\n")).to eq [
      element('p', {}, ['foo', "\n", '  donkey', "\n", 'giraffe', "\n", '  zebra'])
    ]
  end

  it 'includes empty lines in raw content' do
    expect(parse("#p foo\n\n  donkey\n\n    giraffe\n")).to eq [
      element('p', {}, ['foo', "\n", "\n", 'donkey', "\n", "\n", '  giraffe'])
    ]
  end

  it 'does not include line break after empty block element and before data lines' do
    expect(parse("#p\n  donkey\n")).to eq [
      element('p', {}, ['donkey'])
    ]
  end

  it 'parses inline element in data lines' do
    expect(parse("#p\n  %em{donkey}")).to eq [
      element('p', {}, [element('em', {}, ['donkey'])])
    ]
  end

  it 'parses empty attributes' do
    expect(parse('#p[] hi')).to eq [
      element('p', {}, ['hi'])
    ]
  end

  it 'parses single attribute' do
    expect(parse('#p[foo=bar] hi')).to eq [
      element('p', { 'foo' => 'bar' }, ['hi'])
    ]
  end

  it 'parses attribute with dash' do
    expect(parse('#p[intended-audience=learner] hi')).to eq [
      element('p', { 'intended-audience' => 'learner' }, ['hi'])
    ]
  end

  it 'parses attribute with numbers' do
    expect(parse('#p[is-over-9000=yup] hi')).to eq [
      element('p', { 'is-over-9000' => 'yup' }, ['hi'])
    ]
  end

  it 'parses attribute with underscore' do
    expect(parse('#p[intended_audience=learner] hi')).to eq [
      element('p', { 'intended_audience' => 'learner' }, ['hi'])
    ]
  end

  it 'parses attribute with uppercase letters' do
    expect(parse('#p[IntendedAudience=learner] hi')).to eq [
      element('p', { 'IntendedAudience' => 'learner' }, ['hi'])
    ]
  end

  it 'does not parse attributes starting with -' do
    expect { parse('#p[-this=is dog] hello yes') }.to raise_error(DMark::Parser::ParserError)
  end

  it 'does not parse attributes starting with _' do
    expect { parse('#p[_this=is dog] hello yes') }.to raise_error(DMark::Parser::ParserError)
  end

  it 'does not parse attributes starting with a digit' do
    expect { parse('#p[4this=is dog] hello yes') }.to raise_error(DMark::Parser::ParserError)
  end

  it 'parses single value-less attribute' do
    expect(parse('#p[foo] hi')).to eq [
      element('p', { 'foo' => 'foo' }, ['hi'])
    ]
  end

  it 'parses multiple attributes' do
    expect(parse('#p[foo=bar,qux=donkey] hi')).to eq [
      element('p', { 'foo' => 'bar', 'qux' => 'donkey' }, ['hi'])
    ]
  end

  it 'parses multiple value-less attributes' do
    expect(parse('#p[foo,qux] hi')).to eq [
      element('p', { 'foo' => 'foo', 'qux' => 'qux' }, ['hi'])
    ]
  end

  it 'parses escaped attributes' do
    expect(parse('#p[foo=%],bar=%%,donkey=%,] hi')).to eq [
      element('p', { 'foo' => ']', 'bar' => '%', 'donkey' => ',' }, ['hi'])
    ]
  end

  it 'parses attributes in empty block' do
    expect(parse("#p[foo=bar]\n  hi")).to eq [
      element('p', { 'foo' => 'bar' }, ['hi'])
    ]
  end

  it 'parses block start on next line properly' do
    expect(parse("#p\n  this is not a child block.")).to eq [
      element('p', {}, ['this is not a child block.'])
    ]
  end

  it 'parses block start on next line with spacey' do
    expect(parse("#p\n  foo.bar")).to eq [
      element('p', {}, ['foo.bar'])
    ]
  end

  it 'parses child block without content' do
    expect(parse("#ul\n  #li\n    #p You can.")).to eq [
      element(
        'ul', {},
        [
          element(
            'li', {},
            [
              element('p', {}, ['You can.'])
            ]
          )
        ]
      )
    ]
  end

  it 'parses child block without content at end' do
    expect(parse("#ul\n  #li")).to eq [
      element(
        'ul', {},
        [
          element('li', {}, [])
        ]
      )
    ]
  end

  it 'parses child block with attributes' do
    expect(parse("#ul\n  #li[foo]")).to eq [
      element(
        'ul', {},
        [
          element('li', { 'foo' => 'foo' }, [])
        ]
      )
    ]
  end

  it 'parses document starting with blank lines' do
    expect(parse("  \n \n#p Hi!")).to eq [
      element('p', {}, ['Hi!'])
    ]
  end

  it 'parses escaped indented line' do
    expect(parse("#listing\n  %#h1 Foo\n")).to eq [
      element('listing', {}, ['#', 'h1 Foo'])
    ]
  end

  it 'parses escaped indented line with attributes' do
    expect(parse("#listing\n  %#h1[donkey] Foo\n")).to eq [
      element('listing', {}, ['#', 'h1[donkey] Foo'])
    ]
  end

  it 'does not parse percent escapes' do
    expect { parse('#p %ref[url=https://github.com/pulls?q=is%3Aopen+user%3Ananoc]{eek}') }
      .to raise_error(DMark::Parser::ParserError, 'parse error at line 1, col 43: expected "%", "," or "]" after "%", but got "3"')
  end

  it 'does not parse attribute values ending with an end-of-file' do
    expect { parse('#p %ref[url=hello') }
      .to raise_error(DMark::Parser::ParserError, 'parse error at line 1, col 18: unexpected file end in attribute value')
  end

  it 'does not parse attribute values ending with a line break' do
    expect { parse("#p %ref[url=hello\n") }
      .to raise_error(DMark::Parser::ParserError, 'parse error at line 1, col 18: unexpected line break in attribute value')
  end

  it 'does not parse escaped attribute values ending with an end-of-file' do
    expect { parse('#p %ref[url=hello%') }
      .to raise_error(DMark::Parser::ParserError, 'parse error at line 1, col 19: unexpected file end in attribute value')
  end

  it 'does not parse escaped attribute values ending with a line break' do
    expect { parse("#p %ref[url=hello%\n") }
      .to raise_error(DMark::Parser::ParserError, 'parse error at line 1, col 19: unexpected line break in attribute value')
  end

  it 'does not parse' do
    expect { parse('#') }.to raise_error(DMark::Parser::ParserError)
    expect { parse('p') }.to raise_error(DMark::Parser::ParserError)
    expect { parse('0') }.to raise_error(DMark::Parser::ParserError)
    expect { parse('p0') }.to raise_error(DMark::Parser::ParserError)
    expect { parse('#0') }.to raise_error(DMark::Parser::ParserError)
    expect { parse('#p %') }.to raise_error(DMark::Parser::ParserError)
    expect { parse('#p }') }.to raise_error(DMark::Parser::ParserError)
  end
end
