class Entry < ActiveRecord::Base
  belongs_to :credit_account, :class_name=>'Account', :foreign_key=>'credit_account_id'
  belongs_to :debit_account, :class_name=>'Account', :foreign_key=>'debit_account_id'
  belongs_to :entity
  
  @scaffold_fields = %w'date reference entity debit_account credit_account amount memo cleared'
  @other_account = nil
  attr_accessor :other_account
  
  def income
    self[:income].to_money
  end
  
  def expense
    self[:expense].to_money
  end
  
  def profit
    (self[:income].to_f - self[:expense].to_f).to_money
  end
  
  def money_amount
    amount.to_money
  end
  
  def main_account=(account)
    @other_account = if account.id == credit_account_id
      self[:amount] *= -1 if amount
      debit_account
    else
      credit_account
    end
  end
end
