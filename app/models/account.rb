class Account < Sequel::Model
  include ValuesSummingTo
  many_to_one :account_type
  one_to_many :credit_entries, :class_name=>'Entry', :key=>:credit_account_id, :eager=>[:credit_account, :debit_account, :entity], :order=>:date.desc
  one_to_many :debit_entries, :class_name=>'Entry', :key=>:debit_account_id, :eager=>[:credit_account, :debit_account, :entity], :order=>:date.desc
  one_to_many(:recent_credit_entries, :class_name=>'Entry', :key=>:credit_account_id, :eager=>[:credit_account, :debit_account, :entity], :order=>:date.desc){|ds| ds.limit(25)}
  one_to_many(:recent_debit_entries, :class_name=>'Entry', :key=>:debit_account_id, :eager=>[:credit_account, :debit_account, :entity], :order=>:date.desc){|ds| ds.limit(25)}
  @scaffold_select_order = :name
  @scaffold_fields = [:name, :account_type, :hidden, :description]
  @scaffold_column_types = {:description=>:text}
  @scaffold_column_options_hash = {:description=>{:cols=>'50', :rows=>'4'}}
  @scaffold_associations = [:recent_credit_entries, :recent_debit_entries]
  @scaffold_session_value = :user_id
  
  def_dataset_method(:for_select) do
    all.collect{|account|[account.scaffold_name, account.id]}
  end
  
  subset(:register_accounts, :account_type_id=>[1,2])
  subset(:unhidden, ~:hidden)

  def self.user(user_id)
    filter(:user_id=>user_id).order(:name)
  end

  def cents(dollars)
    (dollars * 100).to_i
  end
  
  def entries(limit=nil, conds=nil)
    ds = Entry
    ds = ds.filter(conds) if conds
    ds = ds.limit(limit) if limit
    ds.eager(:entity, :credit_account, :debit_account).filter(:user_id=>user_id, id=>[:credit_account_id, :debit_account_id]).order(:date.desc, :reference.desc, :amount.desc).all.collect do |entry|
      entry.main_account = self
      entry
    end
  end

  def entries_reconciling_to(reconciled_balance, definite_entries = nil, max_seconds = nil)
    entries = entries_to_reconcile
    if definite_entries
      definite_entries, entries = entries.partition{|entry| definite_entries.include?(entry.id)}
      definite_sum = sum(definite_entries.collect{|x| x.amount})
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
      Entry.eager(:entity).filter(:"#{type}_account_id"=>id, :user_id=>user_id).filter(~:cleared).order(:date, :reference, :amount.desc)
    else
      entries(nil, ~:cleared)
    end
  end

  def last_entry_for_entity(entity)
    Entry.eager_graph(:entity).filter(id=>[:credit_account_id, :debit_account_id], :entity__name=>entity, :entries__user_id=>user_id).order(:date.desc, :reference.desc, :amount.desc).first
  end

  def money_balance
    balance.to_money
  end

  def next_check_number
    return '' if account_type_id != 1
    return '' unless entry = Entry.filter({id=>[:credit_account_id, :debit_account_id], :user_id=>user_id} & "reference ~ E'^\\\\d+$'".lit).order(:reference.desc).first
    return '' unless entry.reference.to_i > 0
    (entry.reference.to_i+1).to_s
  end

  def scaffold_name
    name[0..30]
  end

  def unreconciled_balance
    balance - Entry.filter(id=>[:credit_account_id, :debit_account_id], :user_id=>user_id).filter(~:cleared).get(:sum[{{:credit_account_id => id}=>:amount * -1}.case(:amount)]).to_f
  end
end
