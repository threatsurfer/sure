class UpBankItemsController < ApplicationController
  before_action :set_up_bank_item, only: [ :show, :destroy, :sync ]
  before_action :require_admin!, only: [ :new, :create, :destroy, :sync ]

  def index
    @up_bank_items = Current.family.up_bank_items.active.ordered
    render layout: "settings"
  end

  def show
  end

  def new
    @up_bank_item = Current.family.up_bank_items.build
  end

  def create
    setup_token = up_bank_item_params[:setup_token]

    if setup_token.blank?
      redirect_to new_up_bank_item_path, alert: "Token cannot be blank."
      return
    end

    begin
      @up_bank_item = Current.family.create_up_bank_item!(
        setup_token: setup_token,
        item_name: up_bank_item_params[:name]
      )

      @up_bank_item.sync_later

      redirect_to accounts_path, notice: "Up Bank connected successfully.", status: :see_other
    rescue Provider::UpBank::UpBankError => e
      Rails.logger.error("Up Bank connection error: #{e.message}")
      redirect_to new_up_bank_item_path, alert: "Could not connect: #{e.message}", status: :see_other
    rescue => e
      Rails.logger.error("Up Bank connection unexpected error: #{e.message}")
      redirect_to new_up_bank_item_path, alert: "An unexpected error occurred.", status: :see_other
    end
  end

  def destroy
    @up_bank_item.destroy_later
    redirect_to accounts_path, notice: "Up Bank disconnected.", status: :see_other
  end

  def sync
    unless @up_bank_item.syncing?
      @up_bank_item.sync_later
    end

    respond_to do |format|
      format.html { redirect_back_or_to accounts_path }
      format.json { head :ok }
    end
  end

  private

    def set_up_bank_item
      @up_bank_item = Current.family.up_bank_items.find(params[:id])
    end

    def up_bank_item_params
      params.require(:up_bank_item).permit(:setup_token, :name)
    end
end
