class ReportsController < ApplicationController
  before_filter :require_login
  
  def balance_sheet
    @assets = Account.find(:all, :conditions=>["user_id = ? AND account_type_id = 1 AND (NOT hidden OR balance != 0)", session[:user_id]], :order=>'name')
    @liabilities = Account.find(:all, :conditions=>["user_id = ? AND account_type_id = 2 AND (NOT hidden OR balance != 0)", session[:user_id]], :order=>'name')
  end
  
  def income_expense
    sql =<<-SQL
    SELECT EXTRACT(YEAR FROM entries.date)::text || to_char(-1*EXTRACT(MONTH FROM entries.date), '00') AS month,
    SUM(CASE WHEN account_type_id != 3 THEN 0 WHEN debit_account_id = accounts.id THEN -amount ELSE amount END) AS income,
    SUM(CASE WHEN account_type_id != 4 THEN 0 WHEN debit_account_id = accounts.id THEN amount ELSE -amount END) AS expense,
    SUM(CASE WHEN account_type_id != 1 THEN 0 WHEN debit_account_id = accounts.id THEN amount ELSE -amount END) AS assets,
    SUM(CASE WHEN account_type_id != 2 THEN 0 WHEN debit_account_id = accounts.id THEN -amount ELSE amount END) AS liabilities
    FROM accounts 
    INNER JOIN entries ON debit_account_id = accounts.id OR credit_account_id = accounts.id
    WHERE entries.date > (SELECT MAX(date) FROM entries WHERE user_id = #{session[:user_id]}) - '1 year 1 month'::interval AND accounts.user_id = #{session[:user_id]}
    GROUP BY EXTRACT(YEAR FROM entries.date)::text || to_char(-1*EXTRACT(MONTH FROM entries.date), '00')
    ORDER BY month DESC
    SQL
    @months = Entry.find_by_sql(sql)[0...-1]
  end
  
  def net_worth
    account = Account.find_by_sql("SELECT SUM(CASE WHEN account_type_id = 1 THEN balance ELSE 0 END) AS assets, -SUM(CASE WHEN account_type_id = 2 THEN balance ELSE 0 END) AS liabilities FROM accounts WHERE user_id = #{session[:user_id]}")[0]
    @assets, @liabilities = account[:assets].to_f, account[:liabilities].to_f
    income_expense
  end
  
  def earning_spending
    @accounts = []
    @max_date = Date.today
    Entry.transaction do
      sql = "SELECT MAX(date) FROM entries WHERE user_id = #{session[:user_id]}"
      dates = Entry.connection.execute(sql)
      return unless dates.rows.length > 0
      max_date = dates[0][0]
      sql =<<-SQL
      SELECT accounts.account_type_id, accounts.name, #{(0...12).to_a.collect{|i| "\nSUM(CASE WHEN extract(month from 
      age((('#{max_date}'::date + 1) - (extract(day from '#{max_date}'::date)::integer)), 
      ((entries.date + 1) - (extract(day from entries.date)::integer)))) != #{i} THEN 0 WHEN debit_account_id = accounts.id THEN amount ELSE -amount END)"}.join(",")}
      FROM accounts 
      INNER JOIN entries ON debit_account_id = accounts.id OR credit_account_id = accounts.id
      WHERE (accounts.account_type_id IN (3,4)) AND age((('#{max_date}'::date + 1) - (extract(day from '#{max_date}'::date)::integer)), ((entries.date + 1) - (extract(day from entries.date)::integer))) < '1 year'::interval AND accounts.user_id = #{session[:user_id]}
      GROUP BY accounts.account_type_id, accounts.name
      ORDER BY account_type_id DESC, name
      SQL
      @max_date = Date.parse(max_date)
      @accounts = Account.connection.execute(sql)
    end
  end
end
