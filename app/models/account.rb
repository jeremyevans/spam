class Account < ActiveRecord::Base
  has_many :credit_entries, :class_name=>'Entry', :foreign_key=>'credit_account_id'
  has_many :debit_entries, :class_name=>'Entry', :foreign_key=>'debit_account_id'
  @scaffold_select_order = 'name'
  @scaffold_fields = %w'name account_type description hidden credit_limit'

  def self.for_select
    find(:all, :order=>'name').collect{|account|[account.scaffold_name, account.id]}
  end
  
  def self.unhidden_register_accounts 
    find(:all, :conditions=>"NOT hidden AND account_type IN ('Bank','CCard')", :order=>'name') 
  end
  
  def entries(limit=nil)
    Entry.find(:all, :include=>[:entity, :credit_account, :debit_account], :conditions=>["? IN (entries.credit_account_id, entries.debit_account_id)", id], :order=>"date DESC, (CASE WHEN reference ~ '^\\\\d{4}$' THEN reference::INTEGER ELSE 0 END) DESC, amount DESC", :limit=>limit).collect do |entry| 
      entry.main_account = self
      entry
    end
  end

  def entries_to_reconcile(type)
    Entry.find(:all, :include=>:entity, :conditions=>["entries.#{type}_account_id = ? AND NOT cleared", id], :order=>"date DESC, (CASE WHEN reference ~ '^\\\\d{4}$' THEN reference::INTEGER ELSE 0 END) DESC, amount DESC")
  end

  def last_entry_for_entity(entity)
    Entry.find(:first, :include=>[:entity, :credit_account, :debit_account], :conditions=>["? IN (entries.credit_account_id, entries.debit_account_id) AND entries_entity.name = ?", id, entity], :order=>"date DESC, (CASE WHEN reference ~ '^\\\\d{4}$' THEN reference::INTEGER ELSE 0 END) DESC, amount DESC")
  end

  def money_balance
    balance.to_money
  end

  def next_check_number
    return '' if account_type != 'Bank'
    self.class.count_by_sql(["SELECT reference::int + 1 AS reference FROM entries WHERE ? in (debit_account_id, credit_account_id) AND reference ~ '^\\\\d{4}$' ORDER BY reference DESC LIMIT 1;", id]).to_s
  end

  def scaffold_name
    name[0..30]
  end

  def unreconciled_balance
    (balance - connection.select_one("SELECT SUM((CASE WHEN credit_account_id = #{id} THEN -1 * amount ELSE amount END)) FROM entries WHERE #{id} IN (debit_account_id, credit_account_id) AND NOT cleared")['sum'].to_f).to_money
  end
end
