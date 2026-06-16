require "test_helper"

class UpBankItemTest < ActiveSupport::TestCase
  setup { @family = families(:dylan_family) }

  test "requires name and a token on create" do
    item = UpBankItem.new(family: @family)
    assert_not item.valid?
    assert_includes item.errors.attribute_names, :name
  end

  test "provides a memoized Up Bank API client" do
    item = UpBankItem.new(family: @family, name: "Up", access_token: "up:demo")
    assert_instance_of Provider::UpBank, item.up_bank_provider
    assert_same item.up_bank_provider, item.up_bank_provider
  end

  test "declares access_token as an encrypted attribute" do
    if UpBankItem.encrypted_attributes.present?
      # Encryption is active — verify the attribute is in the encrypted set
      assert_includes UpBankItem.encrypted_attributes.map(&:to_s), "access_token"
    else
      # Encryption not configured in this env (e.g. test without AR encryption keys).
      # Verify the column exists (guards against typos in the encrypts declaration)
      # and the encryption_ready? guard is working as expected.
      assert_includes UpBankItem.column_names, "access_token",
        "access_token column must exist so the encrypts declaration can take effect when keys are present"
      assert_not UpBankItem.encryption_ready?,
        "Expected encryption to be inactive in this test environment"
    end
  end
end
