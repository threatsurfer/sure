class AddUpBankAccountIdToAccounts < ActiveRecord::Migration[7.2]
  def change
    add_column :accounts, :up_bank_account_id, :uuid
    add_index  :accounts, :up_bank_account_id
  end
end
