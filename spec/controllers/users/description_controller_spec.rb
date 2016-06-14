require 'spec_helper'

describe Users::DescriptionController, type: :controller, vcr: { cassette_name: 'controllers_users_description_controller' } do
  let(:user) { create(:user) }

  let(:procedure) { create(:procedure, :with_two_type_de_piece_justificative, :with_type_de_champ, cerfa_flag: true) }
  let(:dossier) { create(:dossier, procedure: procedure, user: user) }

  let(:dossier_id) { dossier.id }
  let(:bad_dossier_id) { Dossier.count + 10000 }

  let(:name_piece_justificative) { 'dossierPDF.pdf' }
  let(:name_piece_justificative_0) { 'piece_justificative_0.pdf' }
  let(:name_piece_justificative_1) { 'piece_justificative_1.pdf' }

  let(:cerfa_pdf) { Rack::Test::UploadedFile.new("./spec/support/files/#{name_piece_justificative}", 'application/pdf') }
  let(:piece_justificative_0) { Rack::Test::UploadedFile.new("./spec/support/files/#{name_piece_justificative_0}", 'application/pdf') }
  let(:piece_justificative_1) { Rack::Test::UploadedFile.new("./spec/support/files/#{name_piece_justificative_1}", 'application/pdf') }

  before do
    allow(ClamavService).to receive(:safe_file?).and_return(true)

    sign_in dossier.user
  end

  describe 'GET #show' do
    context 'user is not connected' do
      before do
        sign_out dossier.user
      end

      it 'redirects to users/sign_in' do
        get :show, dossier_id: dossier_id
        expect(response).to redirect_to('/users/sign_in')
      end
    end

    it 'returns http success' do
      get :show, dossier_id: dossier_id
      expect(response).to have_http_status(:success)
    end

    it 'redirection vers start si mauvais dossier ID' do
      get :show, dossier_id: bad_dossier_id
      expect(response).to redirect_to(root_path)
    end

    it_behaves_like "not owner of dossier", :show

    describe 'before_action authorized_routes?' do
      context 'when dossier does not have a valid state' do
        before do
          dossier.state = 'validated'
          dossier.save

          get :show, dossier_id: dossier.id
        end

        it { is_expected.to redirect_to root_path }
      end
    end
  end

  describe 'POST #create' do
    let(:timestamp) { Time.now }
    let(:nom_projet) { 'Projet de test' }
    let(:description) { 'Description de test Coucou, je suis un saut à la ligne Je suis un double saut  la ligne.' }

    context 'Tous les attributs sont bons' do
      # TODO separer en deux tests : check donnees et check redirect
      describe 'Premier enregistrement des données' do
        before do
          dossier.draft!
          post :create, dossier_id: dossier_id, nom_projet: nom_projet, description: description
          dossier.reload
        end

        it "redirection vers la page recapitulative" do
          expect(response).to redirect_to("/users/dossiers/#{dossier_id}/recapitulatif")
        end

        it 'etat du dossier est soumis' do
          expect(dossier.state).to eq('initiated')
        end
      end

      # TODO changer les valeurs des champs et check in bdd
      context 'En train de manipuler un dossier non brouillon' do
        before do
          dossier.initiated!
          post :create, dossier_id: dossier_id, nom_projet: nom_projet, description: description
          dossier.reload
        end

        it 'Redirection vers la page récapitulatif' do
          expect(response).to redirect_to("/users/dossiers/#{dossier_id}/recapitulatif")
        end

        it 'etat du dossier n\'est pas soumis' do
          expect(dossier.state).not_to eq('draft')
        end
      end
    end

    context 'Attribut(s) manquant(s)' do
      subject {
        post :create,
             dossier_id: dossier_id,
             nom_projet: nom_projet,
             description: description
      }
      before { subject }

      context 'nom_projet empty' do
        let(:nom_projet) { '' }
        it { is_expected.to render_template(:show) }
        it { expect(flash[:alert]).to be_present }
      end
    end

    context 'Quand la procédure accepte les CERFA' do
      context 'Sauvegarde du CERFA PDF', vcr: { cassette_name: 'controllers_users_description_controller_save_cerfa' } do
        before do
          post :create, dossier_id: dossier_id,
               nom_projet: nom_projet,
               description: description,
               cerfa_pdf: cerfa_pdf
          dossier.reload
        end

        context 'when a CERFA PDF is sent', vcr: { cassette_name: 'controllers_users_description_controller_cerfa_is_sent' } do
          subject { dossier.cerfa.first }

          it 'content' do
            if Features.remote_storage
              expect(subject['content']).to eq('cerfa-3dbb3535-5388-4a37-bc2d-778327b9f999.pdf')
            else
              expect(subject['content']).to eq('cerfa.pdf')
            end
          end

          it 'dossier_id' do
            expect(subject.dossier_id).to eq(dossier_id)
          end

          it { expect(subject.user).to eq user }
        end

        context 'les anciens CERFA PDF ne sont pas écrasées' do
          let(:cerfas) { Cerfa.where(dossier_id: dossier_id) }

          before do
            post :create, dossier_id: dossier_id, nom_projet: nom_projet, description: description, cerfa_pdf: cerfa_pdf
          end

          it "il y a deux CERFA PDF pour ce dossier" do
            expect(cerfas.size).to eq 2
          end
        end
      end
    end

    context 'Quand la procédure n\'accepte pas les CERFA' do
      context 'Sauvegarde du CERFA PDF' do
        let!(:procedure) { create(:procedure) }
        before do
          post :create, dossier_id: dossier_id,
               nom_projet: nom_projet,
               description: description,
               cerfa_pdf: cerfa_pdf
          dossier.reload
        end

        context 'un CERFA PDF est envoyé' do
          it { expect(dossier.cerfa_available?).to be_falsey }
        end
      end
    end

    describe 'Sauvegarde des champs' do
      let(:champs_dossier) { dossier.champs }
      let(:dossier_champs_first) { 'test value' }

      before do
        post :create, {dossier_id: dossier_id,
                       nom_projet: nom_projet,
                       description: description,
                       champs: {
                           "'#{dossier.champs.first.id}'" => dossier_champs_first
                       }
                    }
        dossier.reload
      end

      it { expect(dossier.champs.first.value).to eq(dossier_champs_first) }
      it { expect(response).to redirect_to users_dossier_recapitulatif_path }

      context 'when champs value is empty' do
        let(:dossier_champs_first) { '' }

        it { expect(dossier.champs.first.value).to eq(dossier_champs_first) }
        it { expect(response).to redirect_to users_dossier_recapitulatif_path }

        context 'when champs is mandatory' do
          let(:procedure) { create(:procedure, :with_two_type_de_piece_justificative, :with_type_de_champ_mandatory, cerfa_flag: true) }

          it { expect(response).not_to redirect_to users_dossier_recapitulatif_path }
          it { expect(flash[:alert]).to be_present }
        end
      end
    end

    context 'Sauvegarde des pièces justificatives', vcr: { cassette_name: 'controllers_users_description_controller_sauvegarde_pj' } do
      let(:all_pj_type) { dossier.procedure.type_de_piece_justificative_ids }
      before do
        post :create, {dossier_id: dossier_id,
                       nom_projet: nom_projet,
                       description: description,
                       'piece_justificative_'+all_pj_type[0].to_s => piece_justificative_0,
                       'piece_justificative_'+all_pj_type[1].to_s => piece_justificative_1}
        dossier.reload
      end

      describe 'clamav anti-virus presence', vcr: { cassette_name: 'controllers_users_description_controller_clamav_presence' } do
        it 'ClamavService safe_file? is call' do
          expect(ClamavService).to receive(:safe_file?).twice

          post :create, {dossier_id: dossier_id,
                         nom_projet: nom_projet,
                         description: description,
                         'piece_justificative_'+all_pj_type[0].to_s => piece_justificative_0,
                         'piece_justificative_'+all_pj_type[1].to_s => piece_justificative_1}


        end
      end

      context 'for piece 0' do
        subject { dossier.retrieve_last_piece_justificative_by_type all_pj_type[0].to_s }
        it { expect(subject.content).not_to be_nil }
        it { expect(subject.user).to eq user }
      end
      context 'for piece 1' do
        subject { dossier.retrieve_last_piece_justificative_by_type all_pj_type[1].to_s }
        it { expect(subject.content).not_to be_nil }
        it { expect(subject.user).to eq user }
      end
    end
  end

  describe 'POST #pieces_justificatives', vcr: { cassette_name: 'controllers_users_description_controller_pieces_justificatives' } do
    let(:all_pj_type) { dossier.procedure.type_de_piece_justificative_ids }

    subject { patch :pieces_justificatives, {dossier_id: dossier.id,
                                             'piece_justificative_'+all_pj_type[0].to_s => piece_justificative_0,
                                             'piece_justificative_'+all_pj_type[1].to_s => piece_justificative_1} }

    context 'when user is the owner' do
      before do
        sign_in user
      end

      context 'when PJ have no documents' do
        it { expect(dossier.pieces_justificatives.size).to eq 0 }

        context 'when upload two PJ' do
          before do
            subject
            dossier.reload
          end

          it { expect(dossier.pieces_justificatives.size).to eq 2 }
          it { expect(flash[:notice]).to be_present }
          it { is_expected.to redirect_to users_dossier_recapitulatif_path }
        end
      end

      context 'when PJ have already a document', vcr: { cassette_name: 'controllers_users_description_controller_pj_already_exist' } do
        before do
          create :piece_justificative, :rib, dossier: dossier, type_de_piece_justificative_id: all_pj_type[0]
          create :piece_justificative, :contrat, dossier: dossier, type_de_piece_justificative_id: all_pj_type[1]
        end

        it { expect(dossier.pieces_justificatives.size).to eq 2 }

        context 'when upload two PJ', vcr: { cassette_name: 'controllers_users_description_controller_pj_already_exist_upload_2pj' } do
          before do
            subject
            dossier.reload
          end

          it { expect(dossier.pieces_justificatives.size).to eq 4 }
          it { expect(flash[:notice]).to be_present }
          it { is_expected.to redirect_to users_dossier_recapitulatif_path }
        end
      end

      context 'when one of PJs is not valid' do
        let(:piece_justificative_0) { Rack::Test::UploadedFile.new("./spec/support/files/entreprise.json", 'application/json') }

        it { expect(dossier.pieces_justificatives.size).to eq 0 }

        context 'when upload two PJ' do
          before do
            subject
            dossier.reload
          end

          it { expect(dossier.pieces_justificatives.size).to eq 1 }
          it { expect(flash[:alert]).to be_present }
          it { is_expected.to redirect_to users_dossier_recapitulatif_path }
        end
      end
    end

    context 'when user is a guest' do
      let(:guest) { create :user }

      before do
        create :invite, dossier: dossier, email: guest.email, user: guest

        sign_in guest
      end

      context 'when PJ have no documents' do
        it { expect(dossier.pieces_justificatives.size).to eq 0 }

        context 'when upload two PJ' do
          before do
            subject
            dossier.reload
          end

          it { expect(dossier.pieces_justificatives.size).to eq 2 }
          it { expect(flash[:notice]).to be_present }
          it { is_expected.to redirect_to users_dossiers_invite_path(id: guest.invites.find_by_dossier_id(dossier.id).id) }
        end
      end

      context 'when PJ have already a document' do
        before do
          create :piece_justificative, :rib, dossier: dossier, type_de_piece_justificative_id: all_pj_type[0]
          create :piece_justificative, :contrat, dossier: dossier, type_de_piece_justificative_id: all_pj_type[1]
        end

        it { expect(dossier.pieces_justificatives.size).to eq 2 }

        context 'when upload two PJ', vcr: { cassette_name: 'controllers_users_description_controller_upload_2pj' } do
          before do
            subject
            dossier.reload
          end

          it { expect(dossier.pieces_justificatives.size).to eq 4 }
          it { expect(flash[:notice]).to be_present }
          it { is_expected.to redirect_to users_dossiers_invite_path(id: guest.invites.find_by_dossier_id(dossier.id).id) }
        end
      end

      context 'when one of PJs is not valid' do
        let(:piece_justificative_0) { Rack::Test::UploadedFile.new("./spec/support/files/entreprise.json", 'application/json') }

        it { expect(dossier.pieces_justificatives.size).to eq 0 }

        context 'when upload two PJ' do
          before do
            subject
            dossier.reload
          end

          it { expect(dossier.pieces_justificatives.size).to eq 1 }
          it { expect(flash[:alert]).to be_present }
          it { is_expected.to redirect_to users_dossiers_invite_path(id: guest.invites.find_by_dossier_id(dossier.id).id) }
        end
      end
    end
  end
end
