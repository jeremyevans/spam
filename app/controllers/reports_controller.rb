class ReportsController < ApplicationController
  before_filter :require_login
  
  def balance_sheet
    @assets, @liabilities = userAccount.register_accounts.exclude(:hidden & {:balance=>0}).all.partition{|x| x.account_type_id == 1}
  end
  
  def income_expense
    negative_map = {:income=>true, :expense=>false, :assets=>true, :liabilities=>false}
    @months = accounts_entries_ds.select((:entries__date.extract(:year).cast_string + :to_char[:entries__date.extract(:month) * -1, '00']).as(:month),
      *{3=>:income, 4=>:expense, 1=>:assets, 2=>:liabilities}.collect{|i, aliaz|:sum[[[~{:account_type_id=>i},0], [debit_cond, :amount * (negative_map[aliaz] ? -1 : 1)]].case(:amount * (negative_map[aliaz] ? 1 : -1))].as(aliaz)}).
      filter(:entries__date > '1 year 1 month'.cast(:interval) * -1 + userEntry.select(:max[:date])).
      group(:month).order(:month.desc).all
    @months.pop if @months.length > 12
  end
  
  def net_worth
    account = accounts_ds.select(*account_sums(1=>:assets, 2=>:liabilities)).first
    @assets, @liabilities = account[:assets].to_f, -account[:liabilities].to_f
    income_expense
  end
  
  def earning_spending
    @accounts = []
    DB.transaction do
      return unless @max_date = userEntry.get(:max[:date])
      md = @max_date.to_s.cast(:date)
      age = :age[(md + 1) - md.extract(:day).cast_numeric, (:entries__date + 1) - :entries__date.extract(:day).cast_numeric]
      @accounts = accounts_entries_ds.select(:accounts__account_type_id, :accounts__name,
        *(0..12).to_a.collect{|i| :sum[[[~{age.extract(:month) => i}, 0], [debit_cond, :amount * -1]].case(:amount)].as(:"month_#{i}")}).
        filter(:accounts__account_type_id=>[3,4]).
        filter(age < '1 year'.cast(:interval)).
        group(:accounts__account_type_id, :accounts__name).order(:account_type_id.desc, :name).all
    end
  end

  private

  def accounts_ds
    DB[:accounts].filter(:accounts__user_id=>session[:user_id])
  end

  def accounts_entries_ds
    accounts_ds.join(:entries, {:debit_account_id => :accounts__id, :credit_account_id => :accounts__id}.sql_or)
  end

  def account_sums(accounts)
    accounts.to_a.collect{|id, name| :sum[{{:account_type_id=>id}=>:balance}.case(0)].as(name)}
  end

  def debit_cond
    {:debit_account_id=>:accounts__id}
  end
end
