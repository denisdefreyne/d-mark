def parse(s)
  DMark::Parser.new(s).parse
end

def element(name, attributes, children)
  DMark::ElementNode.new(name, attributes, children)
end

describe 'DMark::Parser#parser' do
  it 'parses' do
    expect(parse('')).to eq []
    expect(parse('#p')).to eq [element('p', {}, [])]
    expect(parse('#p hi')).to eq [element('p', {}, ['hi'])]
    expect(parse('#p hi %%')).to eq [element('p', {}, ['hi ', '%'])]
    expect(parse('#p hi %}')).to eq [element('p', {}, ['hi ', '}'])]
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
        ])
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
      element('p', {}, %W(foo \n donkey))
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
    expect(parse("#p\n  %emph{donkey}")).to eq [
      element('p', {}, [element('emph', {}, ['donkey'])])
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
