describe DMark::Lexer do
  let(:lexer) { described_class.new('') }

  describe '#handle_blank_line' do
    subject { lexer.handle_blank_line(0) }

    it 'records pending blank line' do
      expect { subject }.to change { lexer.pending_blanks }
        .from(0)
        .to(1)
    end
  end

  describe '#handle_block_line_without_content' do
    subject { lexer.handle_block_line_without_content(0, '  ', 'donkey', nil) }

    context 'after non-indented line' do
      # FIXME: this does not make sense -- this line shouldn’t be indented!

      before { lexer.element_stack = [] }

      specify do
        expect { subject }.to change { lexer.element_stack }
          .from([])
          .to(['donkey'])
      end

      specify do
        expect { subject }.not_to change { lexer.pending_blanks }
      end
    end

    context 'after equally-indented line' do
      before { lexer.element_stack = ['animals', 'zebra'] }

      specify do
        expect { subject }.to change { lexer.element_stack }
          .from(['animals', 'zebra'])
          .to(['animals', 'donkey'])
      end

      specify do
        expect { subject }.not_to change { lexer.pending_blanks }
      end
    end

    context 'after more-indented line' do
      before { lexer.element_stack = ['animals', 'zebra', 'stripes'] }

      specify do
        expect { subject }.to change { lexer.element_stack }
          .from(['animals', 'zebra', 'stripes'])
          .to(['animals', 'donkey'])
      end

      specify do
        expect { subject }.not_to change { lexer.pending_blanks }
      end
    end
  end
end
