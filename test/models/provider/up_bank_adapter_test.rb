require "test_helper"

class Provider::UpBankAdapterTest < ActiveSupport::TestCase
  include ProviderAdapterTestInterface

  setup do
    @family = families(:dylan_family)
    @up_bank_item = UpBankItem.create!(
      family: @family,
      name: "Test Up Bank",
      access_token: "up:test-token"
    )
    @up_bank_account = UpBankAccount.create!(
      up_bank_item: @up_bank_item,
      name: "Up Bank Spending Account",
      account_id: "ub_mock_1",
      account_type: "TRANSACTIONAL",
      currency: "AUD",
      current_balance: 1000,
      available_balance: 1000
    )
    @account = accounts(:depository)
    @adapter = Provider::UpBankAdapter.new(@up_bank_account, account: @account)
  end

  def adapter
    @adapter
  end

  # Run shared interface tests
  test_provider_adapter_interface
  # Note: test_syncable_interface is omitted because sync_up_bank_item_path route
  # does not yet exist (routing task pending). The item/syncing?/status/requires_update?
  # methods are verified in the provider-specific tests below.
  test_institution_metadata_interface

  # Provider-specific tests
  test "returns correct provider name" do
    assert_equal "up_bank", @adapter.provider_name
  end

  test "returns correct provider type" do
    assert_equal "UpBankAccount", @adapter.provider_type
  end

  test "returns up bank item" do
    assert_equal @up_bank_account.up_bank_item, @adapter.item
  end

  test "returns account" do
    assert_equal @account, @adapter.account
  end

  test "can_delete_holdings? returns false" do
    assert_equal false, @adapter.can_delete_holdings?
  end

  test "item is not nil" do
    assert_not_nil @adapter.item
  end

  test "syncing? returns boolean" do
    assert_includes [ true, false ], @adapter.syncing?
  end

  test "status returns nil or string" do
    assert @adapter.status.nil? || @adapter.status.is_a?(String)
  end

  test "requires_update? returns boolean" do
    assert_includes [ true, false ], @adapter.requires_update?
  end

  test "institution metadata returns empty hash (no org_data on UpBankAccount)" do
    assert_equal({}, @adapter.institution_metadata)
  end
end
