class Entry < Sequel::Model
  many_to_one :credit_account, :class_name=>'Account', :key=>:credit_account_id, :reciprocal=>:credit_entries
  many_to_one :debit_account, :class_name=>'Account', :key=>:debit_account_id, :reciprocal=>:debit_entries
  many_to_one :entity, :reciprocal=>:entries
  
  @scaffold_fields = [:date, :reference, :entity, :credit_account, :debit_account, :amount, :memo, :cleared]
  @scaffold_select_order = [:date, :reference, :amount].map{|s| Sequel.desc(s)}
  @scaffold_include = [:entity, :credit_account, :debit_account]
  @scaffold_auto_complete_options = {:sql_name=>"reference || date::TEXT || entity.name ||  debit_account.name || credit_account.name || entries.amount::TEXT"}
  @scaffold_session_value = :user_id
  @scaffold_use_eager_graph = true
  
  def self.user(user_id)
    filter(:user_id=>user_id)
  end

  dataset_module do
    def with_account(account_id)
      filter(account_id=>[:credit_account_id, :debit_account_id])
    end
  end
  
  def scaffold_name
    "#{date.strftime('%Y-%m-%d')}-#{reference}-#{entity.name if entity}-#{debit_account.name if debit_account}-#{credit_account.name if credit_account}-#{money_amount}"
  end
  
  attr_accessor :other_account
  
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
