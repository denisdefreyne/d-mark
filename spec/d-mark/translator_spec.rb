describe DMark::Translator do
  let(:translator) { translator_class.new(nodes) }
  let(:translator_class) { described_class }

  let(:nodes) do
    [
      DMark::ElementNode.new(
        'para',
        { 'only' => 'web', 'animal' => 'donkey' },
        [
          DMark::ElementNode.new('emph', {}, ['Hello']),
          ' world!'
        ]
      )
    ]
  end

  describe '#run' do
    subject { translator.run }

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

      it { is_expected.to eql('<para only=web animal=donkey><emph>Hello</emph> world!</para>') }
    end
  end
end
