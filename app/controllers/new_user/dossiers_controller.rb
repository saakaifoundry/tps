module NewUser
  class DossiersController < UserController
    before_action :ensure_ownership!, except: [:index, :modifier, :update]
    before_action :ensure_ownership_or_invitation!, only: [:modifier, :update]
    before_action :forbid_invite_submission!, only: [:update]

    def attestation
      send_data(dossier.attestation.pdf.read, filename: 'attestation.pdf', type: 'application/pdf')
    end

    def identite
      @dossier = dossier
      @user = current_user
    end

    def update_identite
      @dossier = dossier

      individual_updated = @dossier.individual.update(individual_params)
      dossier_updated = @dossier.update(dossier_params)

      if individual_updated && dossier_updated
        flash.notice = "Identité enregistrée"

        if @dossier.procedure.module_api_carto.use_api_carto
          redirect_to users_dossier_carte_path(@dossier.id)
        else
          redirect_to modifier_dossier_path(@dossier)
        end
      else
        flash.now.alert = @dossier.errors.full_messages
        render :identite
      end
    end

    def modifier
      @dossier = dossier_with_champs

      # TODO: remove when the champs are unifed
      if !@dossier.autorisation_donnees
        if dossier.procedure.for_individual
          redirect_to identite_dossier_path(@dossier)
        else
          redirect_to users_dossier_path(@dossier)
        end
      end
    end

    # FIXME: remove PiecesJustificativesService
    # delegate draft save logic to champ ?
    def update
      @dossier = dossier_with_champs

      errors = PiecesJustificativesService.upload!(@dossier, current_user, params)

      if champs_params[:dossier] && !@dossier.update(champs_params[:dossier])
        errors += @dossier.errors.full_messages
      end

      if !draft?
        errors += @dossier.champs.select(&:mandatory_and_blank?)
          .map { |c| "Le champ #{c.libelle.truncate(200)} doit être rempli." }
        errors += PiecesJustificativesService.missing_pj_error_messages(@dossier)
      end

      if errors.present?
        flash.now.alert = errors
        render :modifier
      elsif draft?
        flash.now.notice = 'Votre brouillon a bien été sauvegardé.'
        render :modifier
      elsif @dossier.brouillon?
        @dossier.en_construction!
        NotificationMailer.send_notification(@dossier, @dossier.procedure.initiated_mail_template).deliver_now!
        redirect_to merci_dossier_path(@dossier)
      elsif owns_dossier?
        redirect_to users_dossier_recapitulatif_path(@dossier)
      else
        redirect_to users_dossiers_invite_path(@dossier.invite_for_user(current_user))
      end
    end

    def merci
      @dossier = current_user.dossiers.includes(:procedure).find(params[:id])
    end

    def index
      @user_dossiers = current_user.dossiers.includes(:procedure).page(page)
      @dossiers_invites = current_user.dossiers_invites.includes(:procedure).page(page)

      @current_tab = current_tab(@user_dossiers.count, @dossiers_invites.count)

      @dossiers = case @current_tab
      when 'mes-dossiers'
        @user_dossiers
      when 'dossiers-invites'
        @dossiers_invites
      end
    end

    private

    def page
      [params[:page].to_i, 1].max
    end

    def current_tab(mes_dossiers_count, dossiers_invites_count)
      if dossiers_invites_count == 0
        'mes-dossiers'
      elsif mes_dossiers_count == 0
        'dossiers-invites'
      else
        params[:current_tab].presence || 'mes-dossiers'
      end
    end

    # FIXME: require(:dossier) when all the champs are united
    def champs_params
      params.permit(dossier: {
        champs_attributes: [
          :id, :value, :piece_justificative_file, value: [],
          etablissement_attributes: Champs::SiretChamp::ETABLISSEMENT_ATTRIBUTES
        ]
      })
    end

    def dossier
      Dossier.find(params[:id] || params[:dossier_id])
    end

    def dossier_with_champs
      @dossier_with_champs ||= Dossier.with_ordered_champs.find(params[:id])
    end

    def ensure_ownership!
      if !owns_dossier?
        forbidden!
      end
    end

    def ensure_ownership_or_invitation!
      if !dossier.owner_or_invite?(current_user)
        forbidden!
      end
    end

    def forbid_invite_submission!
      if passage_en_construction? && !owns_dossier?
        forbidden!
      end
    end

    def forbidden!
      flash[:alert] = "Vous n'avez pas accès à ce dossier"
      redirect_to root_path
    end

    def individual_params
      params.require(:individual).permit(:gender, :nom, :prenom, :birthdate)
    end

    def dossier_params
      params.require(:dossier).permit(:autorisation_donnees)
    end

    def owns_dossier?
      dossier.user_id == current_user.id
    end

    def passage_en_construction?
      dossier.brouillon? && !draft?
    end

    def draft?
      params[:submit_action] == 'draft'
    end
  end
end
