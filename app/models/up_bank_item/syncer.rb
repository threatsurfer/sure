class UpBankItem::Syncer
  attr_reader :up_bank_item

  def initialize(up_bank_item)
    @up_bank_item = up_bank_item
  end

  def perform_sync(sync)
    # Phase 1: Import accounts + transactions from Up Bank API
    sync.update!(status_text: "Importing accounts from Up Bank...") if sync.respond_to?(:status_text)
    up_bank_item.import_latest_up_bank_data

    # Phase 2: Process each provider account — creates/updates the SURE Account
    # and imports transactions idempotently.
    sync.update!(status_text: "Processing transactions...") if sync.respond_to?(:status_text)
    up_bank_item.up_bank_accounts.each do |uba|
      UpBankAccount::Processor.new(uba).process
    end

    # Phase 3: Mark sync complete and bump freshness timestamp.
    mark_completed(sync)
  rescue => e
    Rails.logger.error("UpBankItem::Syncer - sync error: #{e.class} - #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
    mark_failed(sync, e)
    raise
  end

  # Public: called by Sync after finalization — no-op for Up Bank.
  def perform_post_sync
    # no-op
  end

  private

    def mark_completed(sync)
      sync.start!    if sync.respond_to?(:may_start?) && sync.may_start?
      sync.complete! if sync.respond_to?(:may_complete?) && sync.may_complete?

      # Bump item freshness timestamp (guard column existence — last_synced_at is
      # derived from completed Syncs by Syncable, not a real column on up_bank_items).
      if up_bank_item.has_attribute?(:last_synced_at)
        up_bank_item.update!(last_synced_at: Time.current)
      end

      # Broadcast UI refresh so the Up Bank card and accounts list update without reload.
      begin
        up_bank_item.family.broadcast_refresh
      rescue => e
        Rails.logger.warn("UpBankItem::Syncer broadcast failed: #{e.class} - #{e.message}")
      end
    end

    def mark_failed(sync, error)
      sync.start! if sync.respond_to?(:may_start?) && sync.may_start?

      if sync.respond_to?(:may_fail?) && sync.may_fail?
        sync.fail!
      elsif sync.respond_to?(:status)
        sync.update!(status: :failed)
      end

      sync.update!(error: error.message) if sync.respond_to?(:error)
    end
end
