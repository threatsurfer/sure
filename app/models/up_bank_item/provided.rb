module UpBankItem::Provided
  extend ActiveSupport::Concern

  def up_bank_provider
    @up_bank_provider ||= Provider::UpBank.new(access_token)
  end
end
