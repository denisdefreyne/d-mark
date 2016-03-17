describe DMark::Translator do
  let(:translator) { translator_class.new }
  let(:translator_class) { described_class }

  let(:nodes) do
    [
      DMark::ElementNode.new(
        'para',
        { 'only' => 'web', 'animal' => 'donkey' },
        [
          DMark::ElementNode.new('em', {}, ['Hello']),
          ' world!'
        ]
      )
    ]
  end

  shared_examples 'translates' do
    context 'translator base class' do
      it 'raises error' do
        expect { subject }.to raise_error(
          DMark::Translator::UnhandledNode,
          'Unhandled element node "para"'
        )
      end
    end

    context 'custom translator' do
      let(:translator_class) do
        Class.new(described_class) do
          def handle_string(string, _context)
            [string]
          end

          def handle_element(element, path, context)
            [
              "<#{element.name}",
              element.attributes.map { |k, v| ' ' + [k, v].join('=') }.join,
              '>',
              handle_children(element, path, context),
              "</#{element.name}>"
            ]
          end
        end
      end

      it { is_expected.to eql('<para only=web animal=donkey><em>Hello</em> world!</para>') }

      context 'doing something with context' do
        let(:translator_class) do
          Class.new(described_class) do
            def handle_string(string, context)
              [string, " [parent=#{context[:kind]}]"]
            end

            def handle_element(element, path, context)
              [
                "<#{element.name}",
                element.attributes.map { |k, v| ' ' + [k, v].join('=') }.join,
                '>',
                handle_children(element, path, context.merge(kind: element.name)),
                "</#{element.name}>"
              ]
            end
          end
        end

        it { is_expected.to eql('<para only=web animal=donkey><em>Hello [parent=em]</em> world! [parent=para]</para>') }
      end
    end
  end

  shared_examples 'errors on unknown type' do
    it 'raises' do
      expect { subject }.to raise_error(
        ArgumentError,
        'Cannot handle Symbol'
      )
    end
  end

  describe '.translate' do
    subject { translator_class.translate(nodes) }
    include_examples 'translates'

    context 'unrecognised type' do
      subject { translator_class.translate([:donkey]) }
      include_examples 'errors on unknown type'
    end
  end

  describe '#translate' do
    subject { translator.translate(nodes) }
    include_examples 'translates'

    context 'unrecognised type' do
      subject { translator.translate([:donkey]) }
      include_examples 'errors on unknown type'
    end
  end

  describe '#translate_children' do
    subject { translator.translate_children(nodes[0], path) }
    let(:path) { [] }

    context 'translator base class' do
      it 'raises error' do
        expect { subject }.to raise_error(DMark::Translator::UnhandledNode)
      end
    end

    context 'custom translator' do
      let(:translator_class) do
        Class.new(described_class) do
          def handle_string(string, _context)
            [string]
          end

          def handle_element(element, path, context)
            attributes = element.attributes.merge(parent: path[-1].name)

            [
              "<#{element.name}",
              attributes.map { |k, v| ' ' + [k, v].join('=') }.join,
              '>',
              handle_children(element, path, context),
              "</#{element.name}>"
            ]
          end
        end
      end

      it { is_expected.to eql('<em parent=para>Hello</em> world!') }
    end
  end
end
