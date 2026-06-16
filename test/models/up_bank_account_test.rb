require "test_helper"
class UpBankAccountTest < ActiveSupport::TestCase
  setup { @item = UpBankItem.create!(family: families(:dylan_family), name: "Up", access_token: "t") }

  test "belongs to item; account link is unset by default" do
    uba = @item.up_bank_accounts.create!(account_id: "up-uuid-1", name: "2Up Spending",
            currency: "AUD", account_type: "TRANSACTIONAL", account_subtype: "checking")
    assert_equal @item, uba.up_bank_item
    assert_nil uba.account          # no SURE Account linked yet
    assert_equal 1, @item.reload.up_bank_accounts.count   # restored association works
  end

  test "requires account_id (upstream Up id)" do
    assert_not @item.up_bank_accounts.new(name: "x").valid?
  end
end
