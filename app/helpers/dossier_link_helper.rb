module DossierLinkHelper
  def dossier_linked_path(gestionnaire, dossier)
    if dossier.procedure.gestionnaires.include?(gestionnaire)
      gestionnaire_dossier_path(dossier.procedure, dossier)
    else
      avis = dossier.avis.find_by(gestionnaire: gestionnaire)
      if avis.present?
        gestionnaire_avis_path(avis)
      end
    end
  end
end
