class ReportsController < ApplicationController
  before_filter :require_login
  
  def balance_sheet
    @assets = Account.filter(:user_id => session[:user_id], :account_type_id=> 1).filter(~:hidden | ~{:balance=>0}).order(:name)
    @liabilities = Account.filter(:user_id => session[:user_id], :account_type_id=> 2).filter(~:hidden | ~{:balance=>0}).order(:name)
  end
  
  def income_expense
    negative_map = {:income=>true, :expense=>false, :assets=>true, :liabilities=>false}
    @months = DB[:accounts].select((:entries__date.extract(:year).cast_as(:text).sql_string + :to_char[:entries__date.extract(:month) * -1, '00']).as(:month),
      *{3=>:income, 4=>:expense, 1=>:assets, 2=>:liabilities}.collect{|i, aliaz|:SUM[("CASE WHEN account_type_id != %i THEN 0 WHEN debit_account_id = accounts.id THEN #{'-' if negative_map[aliaz]}amount ELSE #{'-' unless negative_map[aliaz]}amount END" % i).lit].as(aliaz)}).
      join(:entries, {:debit_account_id => :accounts__id, :credit_account_id => :accounts__id}.sql_or).
      filter((:entries__date > '1 year 1 month'.cast_as(:interval) * -1 + DB[:entries].select(:MAX[:date]).filter(:user_id=>session[:user_id])) & {:accounts__user_id=>session[:user_id]}).
      group(:month).order(:month.desc).all
    @months.pop if @months.length > 12
  end
  
  def net_worth
    account = DB[:accounts].select(:sum['CASE WHEN account_type_id = 1 THEN balance ELSE 0 END'.lit].as(:assets), :sum['CASE WHEN account_type_id = 2 THEN balance ELSE 0 END'.lit].as(:liabilities)).
      filter(:user_id=>session[:user_id]).first
    @assets, @liabilities = account[:assets].to_f, -account[:liabilities].to_f
    income_expense
  end
  
  def earning_spending
    @accounts = []
    DB.transaction do
      sql = "SELECT MAX(date) FROM entries WHERE user_id = #{session[:user_id]}"
      return unless @max_date = Entry.filter(:user_id=>session[:user_id]).get(:max[:date])
      @accounts = DB[:accounts].select(:accounts__account_type_id, :accounts__name,
        *(0..12).to_a.collect{|i| :sum["CASE WHEN extract(month from age((('#{@max_date}'::date + 1) - (extract(day from '#{@max_date}'::date)::integer)), ((entries.date + 1) - (extract(day from entries.date)::integer)))) != #{i} THEN 0 WHEN debit_account_id = accounts.id THEN -amount ELSE amount END".lit].as(:"month_#{i}")}).
        join(:entries, {:debit_account_id => :accounts__id, :credit_account_id => :accounts__id}.sql_or).
        filter(:accounts__account_type_id=>[3,4], :accounts__user_id=>session[:user_id]).
        filter(:age[@max_date.to_s.cast_as(:date) + 1 - @max_date.to_s.cast_as(:date).extract(:day).cast_as(:integer), :entries__date + 1 - :entries__date.extract(:day).cast_as(:integer)] < '1 year'.cast_as(:interval)).
        group(:accounts__account_type_id, :accounts__name).order(:account_type_id.desc, :name).all
    end
  end
end
