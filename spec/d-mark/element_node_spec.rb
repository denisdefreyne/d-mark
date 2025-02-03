describe DMark::ElementNode do
  let(:element_node) { described_class.new(name, attributes, children) }

  let(:name) { 'para' }
  let(:attributes) { {} }
  let(:children) { ['Hello!'] }

  describe '#inspect' do
    subject { element_node.inspect }

    context 'without attributes' do
      let(:attributes) { {} }

      it { is_expected.to eql('Element(para, ["Hello!"])') }
    end

    context 'with attributes' do
      let(:attributes) { { 'only' => 'web' } }

      it { is_expected.to eql('Element(para, {"only" => "web"}, ["Hello!"])') }
    end
  end

  describe '#==' do
    subject { element_node == other }

    context 'when other is not an element node' do
      let(:other) { 'donkey' }

      it { is_expected.to be false }
    end

    context 'when other is an element node' do
      context 'when other does not differ' do
        let(:other) { described_class.new(name, attributes, children) }

        it { is_expected.to be true }
      end

      context 'when other differs in name' do
        let(:other) { described_class.new('giraffe', attributes, children) }

        it { is_expected.to be false }
      end

      context 'when other differs in attributes' do
        let(:other) { described_class.new(name, { 'friend' => 'donkey' }, children) }

        it { is_expected.to be false }
      end

      context 'when other differs in children' do
        let(:other) { described_class.new(name, attributes, []) }

        it { is_expected.to be false }
      end
    end
  end
end
