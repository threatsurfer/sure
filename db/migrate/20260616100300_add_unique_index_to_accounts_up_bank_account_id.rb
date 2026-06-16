class AddUniqueIndexToAccountsUpBankAccountId < ActiveRecord::Migration[7.2]
  def change
    remove_index :accounts, :up_bank_account_id, if_exists: true
    add_index :accounts, :up_bank_account_id, unique: true, where: "up_bank_account_id IS NOT NULL", name: "idx_unique_accounts_up_bank_account_id"
  end
end
