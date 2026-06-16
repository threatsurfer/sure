module Family::UpBankConnectable
  extend ActiveSupport::Concern

  included do
    has_many :up_bank_items, dependent: :destroy
  end

  def can_connect_up_bank?
    true # Up Bank doesn't have regional restrictions like Plaid
  end

  def create_up_bank_item!(setup_token:, item_name: nil)
    up_bank_provider = Provider::UpBankAdapter.new
    access_url = up_bank_provider.claim_access_url(setup_token)

    up_bank_item = up_bank_items.create!(
      name: item_name || "Up Bank Connection",
      access_url: access_url
    )

    up_bank_item.sync_later

    up_bank_item
  end
end
