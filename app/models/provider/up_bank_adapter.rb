class Provider::UpBankAdapter < Provider::Base
  include Provider::Syncable
  include Provider::InstitutionMetadata

  # Register this adapter with the factory
  Provider::Factory.register("UpBankAccount", self)

  # Define which account types this provider supports
  def self.supported_account_types
    %w[Depository CreditCard Loan Investment]
  end

  # Returns connection configurations for this provider
  def self.connection_configs(family:)
    return [] unless family.can_connect_up_bank?

    [ {
      key: "up_bank",
      name: "Up Bank",
      description: "Connect to your bank via Up Bank",
      can_connect: true,
      new_account_path: ->(accountable_type, return_to) {
        Rails.application.routes.url_helpers.new_up_bank_item_path(
          accountable_type: accountable_type
        )
      },
      existing_account_path: ->(account_id) {
        Rails.application.routes.url_helpers.select_existing_account_up_bank_items_path(
          account_id: account_id
        )
      }
    } ]
  end

  def provider_name
    "up_bank"
  end

  def sync_path
    Rails.application.routes.url_helpers.sync_up_bank_item_path(item)
  end

  def item
    provider_account.up_bank_item
  end

  def can_delete_holdings?
    false
  end
end
