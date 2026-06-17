# Up Bank provider — fork maintenance runbook

This fork adds a native **Up Bank (AU)** provider to SURE. Branch: `up-bank`.
Built + deployed on the Docker VM (192.168.10.220) as image `sure:upbank`, run via `/opt/sure/compose.yml`.

## Update from upstream
    cd /opt/sure-fork && git fetch upstream && git checkout up-bank
    git merge upstream/main            # conflicts usually only in the shared files listed below
    docker build -t sure:upbank .
    cd /opt/sure && docker compose run --rm web bin/rails db:migrate && docker compose up -d --force-recreate web worker

## Connect / use
Settings -> Providers -> Up Bank -> paste your Up Personal Access Token (read-only; stored encrypted).
Up returns FULL account history (years) on first backfill (heavy, one-time); later syncs are incremental.
HELD (pending) transactions are skipped (up_bank is not in Transaction::PENDING_PROVIDERS).

## Additive files (new; never conflict)
app/models/up_bank_item.rb + up_bank_item/{provided,importer,syncer,sync_complete_event}.rb
app/models/provider/{up_bank,up_bank_adapter}.rb
app/models/up_bank_account.rb + up_bank_account/processor.rb
app/models/family/up_bank_connectable.rb
app/controllers/up_bank_items_controller.rb
app/views/settings/providers/_up_bank_panel.html.erb
db/migrate/2026061610*_*up_bank*.rb

## Shared-file edits (re-apply if upstream changes these)
app/models/provider/metadata.rb (registry entry)
config/routes.rb (resources :up_bank_items)
app/controllers/settings/providers_controller.rb (FAMILY_PANELS, PANEL_SYNCABLE_TYPES, load_provider_items, family_panel_items)
app/models/provider_merchant.rb (enum :source +up_bank)
app/models/data_enrichment.rb (enum :source +up_bank)
app/models/provider_connection_status.rb (PROVIDERS +up_bank)
app/models/account.rb (create_from_up_bank_account)
config/locales/views/settings/en.yml (up_bank_panel keys)

## Deferred polish (cosmetic)
- transactions_helper.rb: format up_bank `extra` in the txn detail view
- accounts/index.html.erb empty-state: include @up_bank_items
