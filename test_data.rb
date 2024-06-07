module Spam
  module TestData
    def load_test_data
      DB[:users].insert(:password_hash=>BCrypt::Password.create("pass"), :name=>"default", :num_register_entries=>35, :id=>1)
      DB[:users].insert(:password_hash=>BCrypt::Password.create("pass2"), :name=>"test", :num_register_entries=>35, :id=>2)
      DB[:account_types].insert(:name=>"Asset", :id=>1)
      DB[:account_types].insert(:name=>"Liability", :id=>2)
      DB[:account_types].insert(:name=>"Income", :id=>3)
      DB[:account_types].insert(:name=>"Expense", :id=>4)
      DB[:accounts].insert(:user_id=>2, :balance=>0, :account_type_id=>1, :name=>"Test", :hidden=>false, :description=>"", :id=>5)
      DB[:accounts].insert(:user_id=>2, :balance=>0, :account_type_id=>2, :name=>"Test Liability", :hidden=>false, :description=>"", :id=>6)
      DB[:accounts].insert(:user_id=>1, :balance=>0, :account_type_id=>2, :name=>"Credit Card", :hidden=>false, :description=>"", :id=>2)
      DB[:accounts].insert(:user_id=>1, :balance=>0, :account_type_id=>1, :name=>"Checking", :hidden=>false, :description=>"", :id=>1)
      DB[:accounts].insert(:user_id=>1, :balance=>0, :account_type_id=>4, :name=>"Food", :hidden=>false, :description=>"", :id=>4)
      DB[:accounts].insert(:user_id=>1, :balance=>0, :account_type_id=>3, :name=>"Salary", :hidden=>false, :description=>"", :id=>3)
      DB[:entities].insert(:user_id=>1, :name=>"Restaurant", :id=>2)
      DB[:entities].insert(:user_id=>1, :name=>"Employer", :id=>1)
      DB[:entities].insert(:user_id=>1, :name=>"Card", :id=>3)
      DB[:entities].insert(:user_id=>2, :name=>"Test", :id=>4)
      DB[:entries].insert(:credit_account_id=>6, :reference=>"", :user_id=>2, :entity_id=>4, :cleared=>false, :amount=>100, :memo=>"", :date=>'2008-06-11', :debit_account_id=>5, :id=>1)

      DB.reset_primary_key_sequence(:users)
      DB.reset_primary_key_sequence(:accounts)
      DB.reset_primary_key_sequence(:entities)
    end
  end
end
