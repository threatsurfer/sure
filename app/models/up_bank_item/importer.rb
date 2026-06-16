class UpBankItem::Importer
  def initialize(item, up_bank_provider:, sync_start_date: nil)
    @item = item
    @provider = up_bank_provider
    @sync_start_date = sync_start_date
  end

  def import
    Rails.logger.info "UpBankItem::Importer - Starting import for item #{@item.id}"
    Rails.logger.info "UpBankItem::Importer - last_synced_at: #{@item.last_synced_at.inspect}" if @item.respond_to?(:last_synced_at)

    @provider.get_accounts.each do |acct|
      attrs = acct["attributes"] || {}
      balance_attrs = attrs.dig("balance") || {}

      uba = @item.up_bank_accounts.find_or_initialize_by(account_id: acct["id"])
      uba.assign_attributes(
        name:             attrs["displayName"],
        currency:         balance_attrs["currencyCode"],
        current_balance:  cents_to_d(balance_attrs["valueInBaseUnits"]),
        account_type:     attrs["accountType"],
        account_subtype:  attrs["accountType"] == "SAVER" ? "savings" : "checking",
        raw_payload:      acct,
        balance_date:     Time.current
      )
      uba.raw_transactions_payload = @provider.get_transactions(
        account_id: acct["id"],
        since:      window_start
      )
      uba.save!
    end
  end

  private

    def cents_to_d(value)
      value.nil? ? nil : (value.to_d / 100)
    end

    # Returns the start of the sync window.
    # First sync (sync_start_date nil, no last_synced_at) → nil → Up returns full history.
    # Subsequent syncs → last_synced_at minus a 30-day buffer (mirrors SimpleFIN pattern).
    def window_start
      return @sync_start_date if @sync_start_date
      return nil unless @item.respond_to?(:last_synced_at) && @item.last_synced_at
      @item.last_synced_at - 30.days
    end
end
