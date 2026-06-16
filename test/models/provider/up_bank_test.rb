require "test_helper"
class Provider::UpBankTest < ActiveSupport::TestCase
  BASE = "https://api.up.com.au/api/v1"
  setup { @client = Provider::UpBank.new("up:demo-token") }

  test "ping is true on 200" do
    stub_request(:get, "#{BASE}/util/ping").to_return(status: 200, body: '{"meta":{"statusEmoji":"⚡"}}')
    assert @client.ping
  end

  test "ping is false on 401" do
    stub_request(:get, "#{BASE}/util/ping").to_return(status: 401, body: "{}")
    assert_not @client.ping
  end

  test "sends Bearer auth header" do
    s = stub_request(:get, "#{BASE}/util/ping").with(headers: { "Authorization" => "Bearer up:demo-token" }).to_return(status: 200, body: "{}")
    @client.ping
    assert_requested s
  end

  test "get_accounts returns the data array" do
    body = { "data" => [ { "id" => "acc1", "attributes" => { "displayName" => "2Up", "accountType" => "TRANSACTIONAL", "balance" => { "currencyCode" => "AUD", "valueInBaseUnits" => 12345 } } } ], "links" => { "next" => nil } }.to_json
    stub_request(:get, "#{BASE}/accounts").to_return(status: 200, body: body, headers: { "Content-Type" => "application/json" })
    accts = @client.get_accounts
    assert_equal "acc1", accts.first["id"]
    assert_equal "TRANSACTIONAL", accts.first.dig("attributes", "accountType")
  end

  test "get_transactions follows links.next pagination" do
    p1 = { "data" => [ { "id" => "t1" } ], "links" => { "next" => "#{BASE}/transactions?page%5Bafter%5D=cursor2" } }.to_json
    p2 = { "data" => [ { "id" => "t2" } ], "links" => { "next" => nil } }.to_json
    stub_request(:get, "#{BASE}/accounts/acc1/transactions").with(query: hash_including({})).to_return(status: 200, body: p1, headers: { "Content-Type" => "application/json" })
    stub_request(:get, "#{BASE}/transactions?page%5Bafter%5D=cursor2").to_return(status: 200, body: p2, headers: { "Content-Type" => "application/json" })
    txns = @client.get_transactions(account_id: "acc1")
    assert_equal %w[t1 t2], txns.map { |t| t["id"] }
  end

  test "raises on non-2xx" do
    stub_request(:get, "#{BASE}/accounts").to_return(status: 500, body: "boom")
    assert_raises(Provider::UpBank::UpBankError) { @client.get_accounts }
  end
end
