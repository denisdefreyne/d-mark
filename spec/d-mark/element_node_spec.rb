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
end
