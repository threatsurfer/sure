require "test_helper"
class UpBankItem::ImporterTest < ActiveSupport::TestCase
  ACCOUNTS = [
    { "id" => "acc-1", "attributes" => { "displayName" => "2Up Spending", "accountType" => "TRANSACTIONAL", "balance" => { "currencyCode" => "AUD", "valueInBaseUnits" => 262575 } } },
    { "id" => "acc-2", "attributes" => { "displayName" => "💰 Savings",   "accountType" => "SAVER",         "balance" => { "currencyCode" => "AUD", "valueInBaseUnits" => 66 } } }
  ]
  TXNS = [ { "id" => "tx-1", "attributes" => { "status" => "SETTLED", "description" => "Woolworths", "amount" => { "currencyCode" => "AUD", "valueInBaseUnits" => -1740 }, "settledAt" => "2026-06-11T03:00:00+10:00" }, "relationships" => { "transferAccount" => { "data" => nil } } } ]

  # minimal stub provider implementing the methods the importer calls
  class StubProvider
    def initialize(accts, txns) = (@accts, @txns = accts, txns)
    def get_accounts = @accts
    def get_transactions(account_id:, since: nil, until_date: nil) = @txns
  end

  setup { @item = UpBankItem.create!(family: families(:dylan_family), name: "Up", access_token: "t") }

  test "upserts one up_bank_account per Up account, stores txns, idempotent" do
    2.times { UpBankItem::Importer.new(@item, up_bank_provider: StubProvider.new(ACCOUNTS, TXNS), sync_start_date: nil).import }
    assert_equal 2, @item.reload.up_bank_accounts.count           # no dupes on 2nd run
    uba = @item.up_bank_accounts.find_by(account_id: "acc-1")
    assert_equal "2Up Spending", uba.name
    assert_equal "checking", uba.account_subtype
    assert_equal 2625.75.to_d, uba.current_balance               # cents -> dollars
    assert_equal "AUD", uba.currency
    assert uba.raw_transactions_payload.present?
    saver = @item.up_bank_accounts.find_by(account_id: "acc-2")
    assert_equal "savings", saver.account_subtype
  end
end
