class Entity < Sequel::Model
  one_to_many :entries
  one_to_many :recent_entries, :class_name=>'Entry', :eager=>[:credit_account, :debit_account], :order=>Sequel.desc(:date), :limit=>25
  
  def self.user(user_id)
    filter(:user_id=>user_id).order(:name)
  end

  dataset_module do
    def auto_complete(name, account_id)
      qualify.
      filter(Sequel.ilike(:name, "%#{name}%")).
      left_join(:entries, {:entity_id=>:id, account_id.to_i=>[:credit_account_id, :debit_account_id]}, :qualify=>:symbol).
      order(Sequel.desc(:entries__date), :name).
      limit(10).
      select_group(:name).
      order{[max(entries__date).desc(:nulls=>:last), :name]}.
      map(:name)
    end
  end

  def short_name
    name[0..30]
  end
end

# Table: entities
# Columns:
#  id      | integer | PRIMARY KEY DEFAULT nextval('entities_id_seq'::regclass)
#  name    | text    | NOT NULL
#  user_id | integer | NOT NULL
# Indexes:
#  entities_pkey  | PRIMARY KEY btree (id)
#  entities_namei | UNIQUE btree (user_id, lower(name))
# Foreign key constraints:
#  entities_user_id_fkey | (user_id) REFERENCES users(id)
# Referenced By:
#  entries | entries_entity_id_fkey | (entity_id) REFERENCES entities(id)
# Triggers:
#  no_updating_entities_user_id | BEFORE UPDATE ON entities FOR EACH ROW EXECUTE PROCEDURE no_updating_user_id()
