describe DMark::Translator do
  let(:translator) { translator_class.new(nodes) }
  let(:translator_class) { described_class }

  let(:nodes) do
    [
      DMark::ElementNode.new(
        'para',
        { 'only' => 'web', 'animal' => 'donkey' },
        ['Hi!']
      )
    ]
  end

  describe '#run' do
    subject { translator.run }

    context 'translator base class' do
      it 'raises NotImplementedError' do
        expect { subject }.to raise_error(NotImplementedError)
      end
    end

    context 'custom translator' do
      let(:translator_class) do
        Class.new(described_class) do
          def handle(node)
            case node
            when String
              out << node
            when DMark::ElementNode
              out << "<#{node.name}"
              out << node.attributes.map { |k, v| ' ' + [k, v].join('=') }.join
              out << '>'
              handle_children(node)
              out << "</#{node.name}>"
            end
          end
        end
      end

      it { is_expected.to eql('<para only=web animal=donkey>Hi!</para>') }
    end
  end
end