class CreateUpBankItems < ActiveRecord::Migration[7.2]
  def change
    create_table :up_bank_items, id: :uuid do |t|
      t.uuid    :family_id, null: false
      t.text    :access_token
      t.string  :name
      t.string  :status, default: "good"
      t.boolean :scheduled_for_deletion, default: false
      t.jsonb   :raw_payload
      t.date    :sync_start_date
      t.timestamps
    end
    add_index :up_bank_items, :family_id
    add_index :up_bank_items, :status
  end
end
