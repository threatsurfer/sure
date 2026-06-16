class UpBankItem < ApplicationRecord
  include Syncable, Provided, Encryptable

  enum :status, { good: "good", requires_update: "requires_update" }, default: :good

  # Virtual attribute for the setup token form field
  attr_accessor :setup_token

  # Encrypt sensitive credentials and raw payloads if ActiveRecord encryption is configured
  if encryption_ready?
    encrypts :access_token, deterministic: true
    encrypts :raw_payload
  end

  belongs_to :family

  validates :name, presence: true
  validates :access_token, presence: true, on: :create

  scope :active,   -> { where(scheduled_for_deletion: false) }
  scope :syncable, -> { active }
  scope :ordered,  -> { order(created_at: :desc) }

  def import_latest_up_bank_data(sync_start_date: nil)
    UpBankItem::Importer.new(self, up_bank_provider:, sync_start_date:).import
  end
end
