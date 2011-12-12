class Entity < Sequel::Model
  one_to_many :entries
  one_to_many :recent_entries, :class_name=>'Entry', :eager=>[:credit_account, :debit_account], :order=>:date.desc, :limit=>25
  @scaffold_fields = [:name]
  @scaffold_select_order = :name
  @scaffold_associations = [:recent_entries]
  @scaffold_auto_complete_options = {}
  @scaffold_session_value = :user_id
  
  def self.user(user_id)
    filter(:user_id=>user_id).order(:name)
  end

  dataset_module do
    def auto_complete(name, account_id)
      qualify.
      filter(:name.ilike("%#{name}%")).
      left_join(:entries, :entity_id=>:id, account_id.to_i=>[:credit_account_id, :debit_account_id]).
      order(:entries__date.desc, :name).
      limit(10).
      select_group(:name).
      order{[max(entries__date).desc(:nulls=>:last), :name]}.
      map(:name)
    end
  end

  def scaffold_name
    name[0..30]
  end
end
