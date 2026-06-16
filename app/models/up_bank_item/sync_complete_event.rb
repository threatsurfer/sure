class UpBankItem::SyncCompleteEvent
  attr_reader :up_bank_item

  def initialize(up_bank_item)
    @up_bank_item = up_bank_item
  end

  def broadcast
    # Update UI for each linked SURE account.
    up_bank_item.accounts.each do |account|
      account.broadcast_sync_complete
    end

    # Replace the Up Bank item card on the Providers page.
    up_bank_item.broadcast_replace_to(
      up_bank_item.family,
      target: "up_bank_item_#{up_bank_item.id}",
      partial: "up_bank_items/up_bank_item",
      locals: { up_bank_item: up_bank_item }
    )

    # Notify the family so the Accounts page refreshes.
    up_bank_item.family.broadcast_sync_complete
  end
end
