class ReportsController < ApplicationController
  BY_YEAR_COND = Proc.new{|k| Sequel.~(Sequel.extract(:year, :entries__date) => k)}

  before_filter :require_login
  
  def balance_sheet
    @assets, @liabilities = userAccount.register_accounts.exclude(Sequel.&(:hidden, :balance=>0)).all.partition{|x| x.account_type_id == 1}
  end
  
  def income_expense
    ue = userEntry
    negative_map = {:income=>true, :expense=>false, :assets=>true, :liabilities=>false}
    @months = accounts_entries_ds.select((Sequel.extract(:year, :entries__date).cast_string + Sequel.function(:to_char, Sequel.extract(:month, :entries__date) * -1, '00')).as(:month),
      *{3=>:income, 4=>:expense, 1=>:assets, 2=>:liabilities}.collect{|i, aliaz| Sequel.function(:sum, Sequel.case([[Sequel.~(:account_type_id=>i),0], [debit_cond, Sequel.*(:amount, (negative_map[aliaz] ? -1 : 1))]], Sequel.*(:amount, (negative_map[aliaz] ? 1 : -1)))).as(aliaz)}).
      filter{entries__date > Sequel.cast('1 year 1 month', :interval) * -1 + ue.select(max(date))}.
      group(:month).reverse_order(:month).all
    @months.pop if @months.length > 12
  end
  
  def net_worth
    account = accounts_ds.select(*account_sums(1=>:assets, 2=>:liabilities)).first
    @assets, @liabilities = account[:assets].to_f, -account[:liabilities].to_f
    income_expense
  end
  
  def earning_spending
    if setup_month_headers
      @accounts = accounts_entries_ds.select(:accounts__name, *by_account_select{|k| Sequel.~(@age.extract(:month) => (@i+=1))}).
       filter(:accounts__account_type_id=>[3,4]).
       filter(@age < Sequel.cast('1 year', :interval)).
       group(:accounts__account_type_id, :accounts__name).order(Sequel.desc(:account_type_id), :name).all
    end
  end

  def earning_spending_by_entity
    if setup_month_headers
      @accounts = entities_entries_ds.select(:entities__name, *by_entity_select{|k| Sequel.~(@age.extract(:month) => (@i+=1))}).
       filter(@age < Sequel.cast('1 year', :interval)).
       filter(Sequel.or(:d__account_type_id => [3,4], :c__account_type_id => [3,4]) & Sequel.or(:d__account_type_id => nil, :c__account_type_id => nil)).
       group(:entities__name).order(:name).all
    end
    render(:action=>'earning_spending')
  end

  def yearly_earning_spending_by_entity
    if setup_year_headers
      @accounts = entities_entries_ds.select(:entities__name, *by_entity_select(&BY_YEAR_COND)).
       filter(Sequel.or(:d__account_type_id => [3,4], :c__account_type_id => [3,4]) & Sequel.or(:d__account_type_id => nil, :c__account_type_id => nil)).
       group(:entities__name).order(:name).all
    end
    render(:action=>'earning_spending')
  end

  def yearly_earning_spending
    if setup_year_headers
      @accounts = accounts_entries_ds.select(:accounts__name, *by_account_select(&BY_YEAR_COND)).
       filter(:accounts__account_type_id=>[3,4]).
       group(:accounts__account_type_id, :accounts__name).order(Sequel.desc(:account_type_id), :name).all
    end
    render(:action=>'earning_spending')
  end

  private

  def accounts_ds
    DB[:accounts].filter(:accounts__user_id=>session[:user_id])
  end

  def accounts_entries_ds
    accounts_ds.join(:entries, Sequel.or(:debit_account_id => :accounts__id, :credit_account_id => :accounts__id))
  end

  def account_sums(accounts)
    accounts.to_a.collect{|id, name| Sequel.function(:sum, Sequel.case({{:account_type_id=>id}=>:balance}, 0)).as(name)}
  end

  def by_account_select
    @headers.map{|k, v| Sequel.function(:sum, Sequel.case([[yield(k), 0], [debit_cond, Sequel.*(:amount, -1)]], :amount)).as(v)}
  end

  def by_entity_select
    @headers.map{|k, v| Sequel.function(:sum, Sequel.case([[yield(k), 0], [{:c__account_type_id => nil}, Sequel.*(:amount, -1)]], :amount)).as(v)}
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
      md = Sequel.cast(max_date.to_s, Date)
      @age = Sequel.function(:age, md + 1 - md.extract(:day).cast_numeric, Sequel.+(:entries__date, 1) - Sequel.extract(:day, :entries__date).cast_numeric)
      @i = -1
      true
    else
      false
    end
  end

  def setup_year_headers
    @accounts = []
    @headers = userEntry.group(Sequel.extract(:year, :date)).reverse_order(:year).select_map(Sequel.extract(:year, :date).cast(Integer).as(:year))
    @headers.map!{|k| [k, :"year_#{k}"]}
    !@headers.empty?
  end
end
