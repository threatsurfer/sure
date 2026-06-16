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

  # AccountProvider link — required for Provider::Factory / sync framework discovery.
  # Mirrors SimplefinAccount which has both the legacy FK and an AccountProvider row.
  has_one :account_provider, as: :provider, dependent: :destroy
  has_one :linked_account, through: :account_provider, source: :account

  validates :account_id, presence: true
  scope :ordered, -> { order(created_at: :asc) }

  # Ensure there is an AccountProvider link for this UpBankAccount and its current Account.
  # Safe and idempotent; returns the AccountProvider or nil if no account is associated yet.
  def ensure_account_provider!
    acct = account
    return nil unless acct

    provider = AccountProvider
      .find_or_initialize_by(provider_type: "UpBankAccount", provider_id: id)
      .tap do |p|
        p.account = acct
        p.save!
      end

    reload_account_provider
    provider
  rescue => e
    Rails.logger.warn("UpBankAccount##{id}: failed to ensure AccountProvider link: #{e.class} - #{e.message}")
    nil
  end
end
