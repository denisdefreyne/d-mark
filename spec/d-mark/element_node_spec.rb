describe DMark::ElementNode do
  let(:element_node) { described_class.new(name, attributes, children) }

  let(:name) { 'para' }
  let(:attributes) { {} }
  let(:children) { ['Hello!'] }

  describe '#inspect' do
    subject { element_node.inspect }

    context 'no attributes' do
      let(:attributes) { {} }

      it { is_expected.to eql('Element(para, ["Hello!"])') }
    end

    context 'attributes' do
      let(:attributes) { { 'only' => 'web' } }

      it { is_expected.to eql('Element(para, {"only"=>"web"}, ["Hello!"])') }
    end
  end

  describe '#==' do
    subject { element_node == other }

    context 'other is not an element node' do
      let(:other) { 'donkey' }

      it { is_expected.to be false }
    end

    context 'other is an element node' do
      context 'other does not differ' do
        let(:other) { described_class.new(name, attributes, children) }

        it { is_expected.to be true }
      end

      context 'other differs in name' do
        let(:other) { described_class.new('giraffe', attributes, children) }

        it { is_expected.to be false }
      end

      context 'other differs in attributes' do
        let(:other) { described_class.new(name, { 'friend' => 'donkey' }, children) }

        it { is_expected.to be false }
      end

      context 'other differs in children' do
        let(:other) { described_class.new(name, attributes, []) }

        it { is_expected.to be false }
      end
    end
  end
end
