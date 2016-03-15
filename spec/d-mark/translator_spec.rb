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
      it 'raises NotImplementedError' do
        expect { subject }.to raise_error(DMark::Translator::UnhandledNode)
      end
    end

    context 'custom translator' do
      let(:translator_class) do
        Class.new(described_class) do
          def handle_string(string)
            [string]
          end

          def handle_element(element, path)
            [
              "<#{element.name}",
              element.attributes.map { |k, v| ' ' + [k, v].join('=') }.join,
              '>',
              handle_children(element, path),
              "</#{element.name}>"
            ]
          end
        end
      end

      it { is_expected.to eql('<para only=web animal=donkey><em>Hello</em> world!</para>') }
    end
  end

  describe '.translate' do
    subject { translator_class.translate(nodes) }
    include_examples 'translates'
  end

  describe '#translate' do
    subject { translator.translate(nodes) }
    include_examples 'translates'
  end

  describe '#translate_children' do
    subject { translator.translate_children(nodes[0], path) }
    let(:path) { [] }

    context 'translator base class' do
      it 'raises NotImplementedError' do
        expect { subject }.to raise_error(DMark::Translator::UnhandledNode)
      end
    end

    context 'custom translator' do
      let(:translator_class) do
        Class.new(described_class) do
          def handle_string(string)
            [string]
          end

          def handle_element(element, path)
            attributes = element.attributes.merge(parent: path[-1].name)

            [
              "<#{element.name}",
              attributes.map { |k, v| ' ' + [k, v].join('=') }.join,
              '>',
              handle_children(element, path),
              "</#{element.name}>"
            ]
          end
        end
      end

      it { is_expected.to eql('<em parent=para>Hello</em> world!') }
    end
  end
end
