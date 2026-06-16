class CreateUpBankAccounts < ActiveRecord::Migration[7.2]
  def change
    create_table :up_bank_accounts, id: :uuid do |t|
      t.uuid    :up_bank_item_id, null: false
      t.string  :name
      t.string  :account_id
      t.string  :currency
      t.decimal :current_balance, precision: 19, scale: 4
      t.decimal :available_balance, precision: 19, scale: 4
      t.string  :account_type
      t.string  :account_subtype
      t.jsonb   :raw_payload
      t.jsonb   :raw_transactions_payload
      t.datetime :balance_date
      t.jsonb   :extra
      t.timestamps
    end
    add_index :up_bank_accounts, :up_bank_item_id
    add_index :up_bank_accounts, :account_id
    add_index :up_bank_accounts, [:up_bank_item_id, :account_id],
              unique: true, where: "account_id IS NOT NULL",
              name: "idx_unique_uba_per_item_and_upstream"
  end
end
