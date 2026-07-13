class UpBankAccount::Processor
  # @param up_bank_account [UpBankAccount] The provider account to process
  def initialize(up_bank_account)
    @uba = up_bank_account
  end

  # Creates/ensures the SURE Account, updates balance, and imports SETTLED transactions.
  # HELD (pending) transactions are always skipped — see include_pending?.
  # Safe to call multiple times — idempotent via find_or_initialize_by in ProviderImportAdapter.
  def process
    account = ensure_account!

    # Ensure AccountProvider row exists so the sync framework can discover this adapter.
    # Mirrors SimplefinAccount#ensure_account_provider! — required for Provider::Factory.
    begin
      @uba.ensure_account_provider!
    rescue => e
      Rails.logger.warn("UpBankAccount::Processor - provider link ensure failed for #{@uba.id}: #{e.class} - #{e.message}")
    end

    adapter = Account::ProviderImportAdapter.new(account)

    # Update balance from the Up Bank snapshot
    if @uba.current_balance
      adapter.update_balance(balance: @uba.current_balance, source: "up_bank")
    end

    # Import each transaction from raw_transactions_payload
    Array(@uba.raw_transactions_payload).each do |tx|
      a = tx["attributes"] || {}

      # Skip HELD (pending) transactions — include_pending? returns false for Up Bank
      # because "up_bank" is not yet wired into Transaction::PENDING_PROVIDERS, so
      # importing HELD would store them as posted entries (wrong).
      next if a["status"] == "HELD" && !include_pending?

      transfer_account_id = tx.dig("relationships", "transferAccount", "data", "id")

      # Map Up Bank's own category (how the user tagged it in the Up app) to the
      # matching SURE category, so synced transactions are categorized automatically.
      # nil when Up has not categorized the transaction (e.g. transfers, income) or
      # when no existing family category matches — category_id: nil leaves the
      # transaction uncategorized, mirroring the Up app.
      category_slug = tx.dig("relationships", "category", "data", "id")

      adapter.import_transaction(
        external_id: "up_bank_#{tx["id"]}",
        source:      "up_bank",
        amount:      -(a.dig("amount", "valueInBaseUnits").to_d / 100),
        currency:    a.dig("amount", "currencyCode") || @uba.currency || "AUD",
        date:        Simplefin::DateUtils.parse_provider_date(a["settledAt"] || a["createdAt"]),
        name:        a["description"],
        notes:       a["message"].presence,
        category_id: (category_slug && category_matcher.match(category_slug)&.id),
        extra:       {
          "up_bank" => {
            "status"              => a["status"],
            "transfer_account_id" => transfer_account_id
          }
        }
      )
    end
  end

  private

    # Whether to import HELD (pending) transactions.
    # Up Bank is not yet listed in Transaction::PENDING_PROVIDERS, so we always return
    # false — importing HELD would create fully-posted entries with wrong state.
    def include_pending?
      # Up: skip HELD (pending) transactions. "up_bank" is not yet wired into
      # Transaction::PENDING_PROVIDERS, so importing HELD would store them as posted.
      false
    end

    # A single category matcher reused across this account's transactions, built from
    # the family's existing categories. Importing is intentionally non-destructive with
    # respect to the family's category structure: we do NOT create Up's taxonomy or
    # bootstrap SURE's defaults here. A family that has no categories (deliberately
    # cleared, or pre-onboarding) simply gets uncategorized transactions, and matching
    # resumes once the user sets up categories through the normal UI flow.
    def category_matcher
      @category_matcher ||= UpBankAccount::CategoryMatcher.new(@uba.up_bank_item.family.categories.to_a)
    end

    # Ensures the linked SURE Account exists.
    # Creates one via Account.create_from_up_bank_account on first run, then reloads
    # the association cache so subsequent calls (including re-runs) see the real record.
    def ensure_account!
      # Reload to avoid a stale nil cache from before the account was created.
      @uba.reload_account

      if @uba.account.present?
        return @uba.account
      end

      # Determine SURE account type from Up Bank's classification.
      # Up Bank uses "TRANSACTIONAL" and "SAVER" subtypes — both map to Depository.
      account_type = map_account_type(@uba.account_type)
      subtype      = @uba.account_subtype.presence

      acct = Account.create_from_up_bank_account(@uba, account_type, subtype)

      # Refresh the in-memory association so the FK-backed has_one reflects the new row.
      @uba.reload_account

      acct
    end

    # Maps Up Bank account_type strings to SURE accountable_type class names.
    def map_account_type(up_type)
      case up_type.to_s.upcase
      when "TRANSACTIONAL", "SAVER" then "Depository"
      when "CREDIT", "CREDITCARD"    then "CreditCard"
      when "LOAN", "MORTGAGE"        then "Loan"
      else "Depository"
      end
    end
end
