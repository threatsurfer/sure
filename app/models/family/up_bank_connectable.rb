module Family::UpBankConnectable
  extend ActiveSupport::Concern

  included do
    has_many :up_bank_items, dependent: :destroy
  end

  def can_connect_up_bank?
    true # Up Bank does not have regional restrictions like Plaid
  end

  # Connects a new Up Bank item using a Personal Access Token (PAT).
  # Up Bank has NO claim-URL exchange — the PAT is the credential.
  # Validates the token via a live ping; raises UpBankConnectionError on failure.
  # Does NOT call sync_later — the controller owns that responsibility.
  def create_up_bank_item!(setup_token:, item_name: nil)
    unless Provider::UpBank.new(setup_token).ping
      raise Provider::UpBank::UpBankError, "Invalid Up Bank token — authentication failed"
    end

    up_bank_items.create!(
      name: item_name.presence || "Up Bank",
      access_token: setup_token
    )
  end
end
