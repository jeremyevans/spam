class ReportsController < ApplicationController
  BY_YEAR_COND = Proc.new{|k| ~{:entries__date.extract(:year) => k}}

  before_filter :require_login
  
  def balance_sheet
    @assets, @liabilities = userAccount.register_accounts.exclude(:hidden & {:balance=>0}).all.partition{|x| x.account_type_id == 1}
  end
  
  def income_expense
    ue = userEntry
    negative_map = {:income=>true, :expense=>false, :assets=>true, :liabilities=>false}
    @months = accounts_entries_ds.select((:entries__date.extract(:year).cast_string + :to_char.sql_function(:entries__date.extract(:month) * -1, '00')).as(:month),
      *{3=>:income, 4=>:expense, 1=>:assets, 2=>:liabilities}.collect{|i, aliaz| :sum.sql_function([[~{:account_type_id=>i},0], [debit_cond, :amount * (negative_map[aliaz] ? -1 : 1)]].case(:amount * (negative_map[aliaz] ? 1 : -1))).as(aliaz)}).
      filter{entries__date > '1 year 1 month'.cast(:interval) * -1 + ue.select(max(date))}.
      group(:month).order(:month.desc).all
    @months.pop if @months.length > 12
  end
  
  def net_worth
    account = accounts_ds.select(*account_sums(1=>:assets, 2=>:liabilities)).first
    @assets, @liabilities = account[:assets].to_f, -account[:liabilities].to_f
    income_expense
  end
  
  def earning_spending
    if setup_month_headers
      @accounts = accounts_entries_ds.select(:accounts__name, *by_account_select{|k| ~{@age.extract(:month) => (@i+=1)}}).
       filter(:accounts__account_type_id=>[3,4]).
       filter(@age < '1 year'.cast(:interval)).
       group(:accounts__account_type_id, :accounts__name).order(:account_type_id.desc, :name).all
    end
  end

  def earning_spending_by_entity
    if setup_month_headers
      @accounts = entities_entries_ds.select(:entities__name, *by_entity_select{|k| ~{@age.extract(:month) => (@i+=1)}}).
       filter(@age < '1 year'.cast(:interval)).
       filter({:d__account_type_id => [3,4], :c__account_type_id => [3,4]}.sql_or & {:d__account_type_id => nil, :c__account_type_id => nil}.sql_or).
       group(:entities__name).order(:name).all
    end
    render(:action=>'earning_spending')
  end

  def yearly_earning_spending_by_entity
    if setup_year_headers
      @accounts = entities_entries_ds.select(:entities__name, *by_entity_select(&BY_YEAR_COND)).
       filter({:d__account_type_id => [3,4], :c__account_type_id => [3,4]}.sql_or & {:d__account_type_id => nil, :c__account_type_id => nil}.sql_or).
       group(:entities__name).order(:name).all
    end
    render(:action=>'earning_spending')
  end

  def yearly_earning_spending
    if setup_year_headers
      @accounts = accounts_entries_ds.select(:accounts__name, *by_account_select(&BY_YEAR_COND)).
       filter(:accounts__account_type_id=>[3,4]).
       group(:accounts__account_type_id, :accounts__name).order(:account_type_id.desc, :name).all
    end
    render(:action=>'earning_spending')
  end

  private

  def accounts_ds
    DB[:accounts].filter(:accounts__user_id=>session[:user_id])
  end

  def accounts_entries_ds
    accounts_ds.join(:entries, {:debit_account_id => :accounts__id, :credit_account_id => :accounts__id}.sql_or)
  end

  def account_sums(accounts)
    accounts.to_a.collect{|id, name| :sum.sql_function({{:account_type_id=>id}=>:balance}.case(0)).as(name)}
  end

  def by_account_select
    @headers.map{|k, v| :sum.sql_function([[yield(k), 0], [debit_cond, :amount * -1]].case(:amount)).as(v)}
  end

  def by_entity_select
    @headers.map{|k,v| :sum.sql_function([
     [yield(k), 0],
     [{:c__account_type_id => nil}, :amount * -1],
     ].case(:amount)).as(v)}
  end

  def debit_cond
    {:debit_account_id=>:accounts__id}
  end

  def entities_entries_ds
    DB[:entities].join(:entries, :entity_id=>:id).
      left_join(:accounts___d, :id=>:entries__debit_account_id, :account_type_id=>[3,4]).
      left_join(:accounts___c, :id=>:entries__credit_account_id, :account_type_id=>[3,4])
  end

  def setup_month_headers
    @accounts, @headers = [], []
    if max_date = userEntry.get{max(date)}
      @headers = (0...12).map{|i| [(max_date << i).strftime('%B %Y'), :"month_#{i}"]}
      md = max_date.to_s.cast(Date)
      @age = :age.sql_function((md + 1) - md.extract(:day).cast_numeric, (:entries__date + 1) - :entries__date.extract(:day).cast_numeric)
      @i = -1
      true
    else
      false
    end
  end

  def setup_year_headers
    @accounts = []
    (@headers = userEntry.group(:date.extract(:year)).order(:year.desc).select_map(:date.extract(:year).cast(Integer).as(:year))).empty?
    @headers.map!{|k| [k, :"year_#{k}"]}
    !@headers.empty?
  end
end
