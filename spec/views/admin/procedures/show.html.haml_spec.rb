require 'spec_helper'

describe 'admin/procedures/show.html.haml', type: :view do
  let(:archived_at) { nil }
  let(:procedure) { create(:procedure, archived_at: archived_at) }

  before do
    assign(:facade, AdminProceduresShowFacades.new(procedure.decorate))
    assign(:procedure, procedure)
  end

  describe 'procedure is draft' do
    context 'when procedure does not have a gestionnare affected' do
      before do
        render
      end

      describe 'publish button is not visible' do
        it { expect(rendered).not_to have_css('a#publish') }
        it { expect(rendered).not_to have_css('button#archive') }
        it { expect(rendered).not_to have_css('a#reenable') }
      end
    end

    context 'when procedure have a gestionnare affected' do
      before do
        create :assign_to, gestionnaire: create(:gestionnaire), procedure: procedure
        render
      end

      describe 'publish button is visible' do
        it { expect(rendered).to have_css('a#publish-procedure') }
        it { expect(rendered).not_to have_css('button#archive') }
        it { expect(rendered).not_to have_css('a#reenable') }
      end

      describe 'procedure link is not present' do
        it { expect(rendered).to have_content('Cette procédure n\'a pas encore été publiée et n\'est donc pas accessible par le public.') }
      end
    end
  end

  describe 'procedure is published' do
    before do
      procedure.publish!('fake_path')
      procedure.reload
      render
    end

    describe 'archive button is visible', js: true do
      it { expect(rendered).not_to have_css('a#publish') }
      it { expect(rendered).to have_css('button#archive') }
      it { expect(rendered).not_to have_css('a#reenable') }
    end

    describe 'procedure link is present' do
      it { expect(rendered).to have_content(commencer_url(procedure_path: procedure.path)) }
    end
  end

  describe 'procedure is archived' do
    before do
      procedure.publish!('fake_path')
      procedure.archive
      procedure.reload
      render
    end

    describe 'Re-enable button is visible' do
      it { expect(rendered).not_to have_css('a#publish') }
      it { expect(rendered).not_to have_css('button#archive') }
      it { expect(rendered).to have_css('a#reenable') }
    end

    describe 'procedure link is present' do
      it { expect(rendered).to have_content(commencer_url(procedure_path: procedure.path)) }
    end
  end
end
