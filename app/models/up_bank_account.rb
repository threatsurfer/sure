class UpBankAccount < ApplicationRecord
  include Encryptable
  if encryption_ready?
    encrypts :raw_payload
    encrypts :raw_transactions_payload
  end

  belongs_to :up_bank_item

  # Mirror SimplefinAccount's SURE-Account association:
  # accounts.up_bank_account_id is the FK on the accounts table.
  has_one :account, dependent: :nullify, foreign_key: :up_bank_account_id

  validates :account_id, presence: true
  scope :ordered, -> { order(created_at: :asc) }
end
