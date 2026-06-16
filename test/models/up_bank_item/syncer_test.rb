require "test_helper"

# Integration test: exercises the full sync pipeline —
# UpBankItem::Syncer → UpBankItem::Importer → UpBankAccount::Processor
# — end-to-end with a stub provider (no real HTTP).
class UpBankItem::SyncerTest < ActiveSupport::TestCase
  # One TRANSACTIONAL account, one outflow transaction of -$17.40 (AUD).
  STUB_ACCOUNTS = [
    {
      "id" => "acc-1",
      "attributes" => {
        "displayName"  => "2Up Spending",
        "accountType"  => "TRANSACTIONAL",
        "balance"      => { "currencyCode" => "AUD", "valueInBaseUnits" => 262575 }
      }
    }
  ].freeze

  STUB_TXNS = [
    {
      "id"            => "tx-1",
      "attributes"    => {
        "status"      => "SETTLED",
        "description" => "Woolworths",
        "message"     => nil,
        "amount"      => { "currencyCode" => "AUD", "valueInBaseUnits" => -1740 },
        "settledAt"   => "2026-06-11T03:00:00+10:00"
      },
      "relationships" => { "transferAccount" => { "data" => nil } }
    }
  ].freeze

  setup do
    @family = families(:dylan_family)
    @item   = UpBankItem.create!(family: @family, name: "Up", access_token: "tok_test")

    # Build a minimal stub that satisfies the provider interface without real HTTP.
    stub = Object.new
    def stub.get_accounts
      [
        {
          "id" => "acc-1",
          "attributes" => {
            "displayName"  => "2Up Spending",
            "accountType"  => "TRANSACTIONAL",
            "balance"      => { "currencyCode" => "AUD", "valueInBaseUnits" => 262575 }
          }
        }
      ]
    end
    def stub.get_transactions(account_id:, since: nil, until_date: nil)
      [
        {
          "id"            => "tx-1",
          "attributes"    => {
            "status"      => "SETTLED",
            "description" => "Woolworths",
            "message"     => nil,
            "amount"      => { "currencyCode" => "AUD", "valueInBaseUnits" => -1740 },
            "settledAt"   => "2026-06-11T03:00:00+10:00"
          },
          "relationships" => { "transferAccount" => { "data" => nil } }
        }
      ]
    end

    @item.stubs(:up_bank_provider).returns(stub)
  end

  # ────────────────────────────────────────────────────────────────────────────
  # Core end-to-end assertion: after one sync a SURE Account exists, the balance
  # matches the Up Bank snapshot, and the transaction entry has correct sign.
  # ────────────────────────────────────────────────────────────────────────────
  test "creates SURE account with correct balance and imports transaction with positive amount" do
    sync = Sync.create!(syncable: @item)
    @item.perform_sync(sync)

    # One SURE Account must exist via the Up Bank account.
    assert_equal 1, @item.accounts.count, "expected exactly one SURE Account after sync"

    account = @item.accounts.first
    assert_equal 2625.75.to_d, account.balance, "balance should be $2625.75 (AUD cents → dollars)"

    # The outflow of -1740 cents should be stored as +17.40 in SURE's convention
    # (outflows are positive amounts on a Depository account).
    entries = account.entries.where(source: "up_bank")
    assert_equal 1, entries.count, "expected exactly one entry with source 'up_bank'"

    entry = entries.first
    assert_equal 17.40.to_d, entry.amount.abs, "entry amount should be 17.40 (abs)"
    assert entry.amount > 0, "outflow from Up Bank should be stored as positive in SURE"
  end

  # ────────────────────────────────────────────────────────────────────────────
  # Idempotency: running the full sync a second time must not duplicate accounts
  # or entries.
  # ────────────────────────────────────────────────────────────────────────────
  test "sync is idempotent — running twice does not duplicate accounts or entries" do
    2.times do
      sync = Sync.create!(syncable: @item)
      @item.perform_sync(sync)
    end

    assert_equal 1, @item.accounts.count,    "still exactly one SURE Account after two syncs"

    account = @item.accounts.first
    up_bank_entries = account.entries.where(source: "up_bank")
    assert_equal 1, up_bank_entries.count, "still exactly one entry after two syncs (idempotent)"
  end

  # ────────────────────────────────────────────────────────────────────────────
  # Sync state machine: the Sync record should be completed after perform_sync.
  # ────────────────────────────────────────────────────────────────────────────
  test "sync record is marked completed after perform_sync" do
    sync = Sync.create!(syncable: @item)
    @item.perform_sync(sync)

    assert_equal "completed", sync.reload.status, "Sync record should be completed"
  end
end
