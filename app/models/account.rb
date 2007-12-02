class Account < ActiveRecord::Base
  include ValuesSummingTo
  belongs_to :account_type
  has_many :credit_entries, :class_name=>'Entry', :foreign_key=>'credit_account_id', :include=>[:credit_account, :debit_account, :entity], :order=>'date DESC'
  has_many :debit_entries, :class_name=>'Entry', :foreign_key=>'debit_account_id', :include=>[:credit_account, :debit_account, :entity], :order=>'date DESC'
  has_many :recent_credit_entries, :class_name=>'Entry', :foreign_key=>'credit_account_id', :include=>[:credit_account, :debit_account, :entity],  :limit=>25, :order=>'date DESC'
  has_many :recent_debit_entries, :class_name=>'Entry', :foreign_key=>'debit_account_id', :include=>[:credit_account, :debit_account, :entity], :limit=>25, :order=>'date DESC'
  @scaffold_select_order = 'accounts.name'
  @scaffold_fields = %w'name account_type hidden description'
  @scaffold_column_types = {'description'=>:text}
  @scaffold_column_options_hash = {'description'=>{:size=>'50x6'}}
  @scaffold_associations = %w'recent_credit_entries recent_debit_entries'
  @scaffold_session_value = :user_id
  attr_protected :balance, :user_id
  
  def self.find_with_user_id(user_id, id)
    account = find(id)
    raise ActiveRecord::RecordNotFound unless account.user_id == user_id
    account
  end
  
  def self.for_select(user_id)
    find(:all, :order=>'name', :conditions=>['user_id = ?', user_id]).collect{|account|[account.scaffold_name, account.id]}
  end
  
  def self.unhidden_register_accounts(user_id)
    find(:all, :conditions=>["NOT hidden AND account_type_id IN (1,2) AND user_id = ?", user_id], :order=>'name') 
  end

  def cents(dollars)
    (dollars * 100).to_i
  end
  
  def entries(limit=nil, conds=nil)
    Entry.find(:all, :include=>[:entity, :credit_account, :debit_account], :conditions=>["accounts.user_id = ? AND #{conds} (? IN (entries.credit_account_id, entries.debit_account_id))", user_id, id], :order=>"date DESC, reference DESC, amount DESC", :limit=>limit).collect do |entry| 
      entry.main_account = self
      entry
    end
  end

  def entries_reconciling_to(reconciled_balance, definite_entries = nil, max_seconds = nil)
    entries = entries_to_reconcile
    if definite_entries
      definite_entries, entries = entries.partition{|entry| definite_entries.include?(entry.id)}
      definite_sum = sum(definite_entries.collect(&:amount))
    else
      definite_sum = 0
    end
    int_value_dict = {}
    entries.each{|entry| (int_value_dict[cents(entry.amount)] ||= []) << entry}
    int_values = entries.collect{|entry| cents(entry.amount)}
    if comb = find_values_summing_to(int_values, cents(reconciled_balance) - cents(unreconciled_balance) - cents(definite_sum), max_seconds)
      if definite_entries
        return comb.collect{|value| int_value_dict[value].shift} + definite_entries
      else
        return comb.collect{|value| int_value_dict[value].shift}
      end
    end
  end

  def entries_to_reconcile(type=nil)
    if type
      Entry.find(:all, :include=>:entity, :conditions=>["entries.#{type}_account_id = ? AND NOT cleared AND entries.user_id = ?", id, user_id], :order=>"date, reference, amount DESC")
    else
      entries(nil, 'NOT cleared AND')
    end
  end

  def last_entry_for_entity(entity)
    Entry.find(:first, :include=>[:entity, :credit_account, :debit_account], :conditions=>["? IN (entries.credit_account_id, entries.debit_account_id) AND entities.name = ? AND accounts.user_id = ?", id, entity, user_id], :order=>"date DESC, reference DESC, amount DESC")
  end

  def money_balance
    balance.to_money
  end

  def next_check_number
    return '' if account_type_id != 1
    return '' unless entry = Entry.find(:first, :conditions=>["? in (debit_account_id, credit_account_id) AND reference ~ E'^\\\\d+$' AND user_id = ?", id, user_id], :order=>'reference DESC')
    return '' unless entry.reference.to_i > 0
    (entry.reference.to_i+1).to_s
  end

  def scaffold_name
    name[0..30]
  end

  def unreconciled_balance
    balance - connection.select_one("SELECT SUM((CASE WHEN credit_account_id = #{id} THEN -1 * amount ELSE amount END)) FROM entries WHERE #{id} IN (debit_account_id, credit_account_id) AND NOT cleared AND user_id = #{user_id}")['sum'].to_f
  end
end
