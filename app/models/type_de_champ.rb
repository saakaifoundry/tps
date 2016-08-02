class TypeDeChamp < ActiveRecord::Base
  enum type_champs: {
           text: 'text',
           textarea: 'textarea',
           date: 'date',
           datetime: 'datetime',
           number: 'number',
           checkbox: 'checkbox',
           civilite: 'civilite',
           email: 'email',
           phone: 'phone',
           address: 'address',
           yes_no: 'yes_no',
           header_section: 'header_section'
       }

  belongs_to :procedure

  has_many :champ, dependent: :destroy

  default_scope { where(private: false) }

  validates :libelle, presence: true, allow_blank: false, allow_nil: false
  validates :type_champ, presence: true, allow_blank: false, allow_nil: false
  # validates :order_place, presence: true, allow_blank: false, allow_nil: false
end