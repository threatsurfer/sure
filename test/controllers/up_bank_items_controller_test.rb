require "test_helper"

class UpBankItemsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  fixtures :users, :families

  setup do
    sign_in users(:family_admin)
    @family = families(:dylan_family)
    @up_bank_item = UpBankItem.create!(
      family: @family,
      name: "Test Up Bank",
      access_token: "up:existing-token"
    )
  end

  # --- create ---

  test "create rejects an invalid token" do
    stub_request(:get, "https://api.up.com.au/api/v1/util/ping").to_return(status: 401, body: "{}")

    assert_no_difference("UpBankItem.count") do
      post up_bank_items_url, params: { up_bank_item: { setup_token: "bad" } }
    end

    assert_response :redirect
  end

  test "create stores a valid token and schedules a sync" do
    stub_request(:get, "https://api.up.com.au/api/v1/util/ping").to_return(status: 200, body: "{}")

    assert_difference("UpBankItem.count", 1) do
      post up_bank_items_url, params: { up_bank_item: { setup_token: "up:good" } }
    end

    assert_redirected_to accounts_path
  end

  test "create with blank token redirects back with alert" do
    assert_no_difference("UpBankItem.count") do
      post up_bank_items_url, params: { up_bank_item: { setup_token: "" } }
    end

    assert_response :redirect
  end

  # --- sync ---

  test "sync enqueues a sync job" do
    post sync_up_bank_item_url(@up_bank_item)
    assert_redirected_to accounts_path
  end

  # --- destroy ---

  test "destroy schedules item for deletion" do
    assert_difference("UpBankItem.count", 0) do # soft delete via destroy_later
      delete up_bank_item_url(@up_bank_item)
    end

    assert_redirected_to accounts_path
    @up_bank_item.reload
    assert @up_bank_item.scheduled_for_deletion?
  end
end
