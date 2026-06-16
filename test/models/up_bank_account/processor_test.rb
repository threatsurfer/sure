require "test_helper"
class UpBankAccount::ProcessorTest < ActiveSupport::TestCase
  TXNS = [
    { "id" => "tx-1", "attributes" => { "status" => "SETTLED", "description" => "Woolworths", "message" => nil, "amount" => { "currencyCode" => "AUD", "valueInBaseUnits" => -1740 }, "settledAt" => "2026-06-11T03:00:00+10:00" }, "relationships" => { "transferAccount" => { "data" => nil } } },
    { "id" => "tx-2", "attributes" => { "status" => "SETTLED", "description" => "Salary", "message" => nil, "amount" => { "currencyCode" => "AUD", "valueInBaseUnits" => 500000 }, "settledAt" => "2026-06-01T09:00:00+10:00" }, "relationships" => { "transferAccount" => { "data" => nil } } },
    { "id" => "tx-3", "attributes" => { "status" => "HELD", "description" => "Pending Coffee", "message" => nil, "amount" => { "currencyCode" => "AUD", "valueInBaseUnits" => -450 }, "createdAt" => "2026-06-15T08:00:00+10:00", "settledAt" => nil }, "relationships" => { "transferAccount" => { "data" => nil } } },
  ]
  setup do
    @item = UpBankItem.create!(family: families(:dylan_family), name: "Up", access_token: "t")
    @uba  = @item.up_bank_accounts.create!(account_id: "acc-1", name: "2Up Spending", currency: "AUD",
              account_type: "TRANSACTIONAL", account_subtype: "checking", current_balance: 2625.75,
              raw_payload: {}, raw_transactions_payload: TXNS)
  end

  test "creates a SURE Account and imports transactions idempotently" do
    2.times { UpBankAccount::Processor.new(@uba).process }
    @uba.reload
    assert @uba.account.present?, "should link a SURE Account"
    assert_equal "AUD", @uba.account.currency
    n = @uba.account.entries.where(source: "up_bank").count
    assert_equal 2, n, "two settled transactions imported, no duplicates after 2 runs (HELD excluded)"
  end

  test "amount sign is inverted: Up outflow (negative cents) becomes positive in SURE" do
    UpBankAccount::Processor.new(@uba).process
    entry = @uba.account.entries.find_by(external_id: "up_bank_tx-1")
    assert_in_delta(17.40, entry.amount.to_f, 0.001)
  end

  test "amount sign is inverted: Up inflow (positive cents) becomes negative in SURE" do
    UpBankAccount::Processor.new(@uba).process
    entry = @uba.account.entries.find_by(external_id: "up_bank_tx-2")
    assert_in_delta(-5000.0, entry.amount.to_f, 0.001)
  end

  test "date is parsed to a real Date from ISO-8601 string" do
    UpBankAccount::Processor.new(@uba).process
    entry = @uba.account.entries.find_by(external_id: "up_bank_tx-1")
    assert_equal Date.new(2026, 6, 11), entry.date
  end

  test "HELD transactions are skipped and not imported" do
    UpBankAccount::Processor.new(@uba).process
    held_entry = @uba.account.entries.find_by(external_id: "up_bank_tx-3")
    assert_nil held_entry, "HELD transaction must not be imported"
  end
end
