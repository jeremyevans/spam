class ReportsController < ApplicationController
  def balance_sheet
    @assets = Account.find(:all, :conditions=>"account_type = 'Bank' AND (NOT hidden OR balance != 0)", :order=>'name')
    @liabilities = Account.find(:all, :conditions=>"account_type = 'CCard' AND (NOT hidden OR balance != 0)", :order=>'name')
  end
  
  def income_expense
    sql =<<-SQL
    SELECT EXTRACT(YEAR FROM entries.date)::text || to_char(-1*EXTRACT(MONTH FROM entries.date), '00') AS month, 
    SUM(CASE WHEN debit_account.account_type = 'Income' AND credit_account.account_type = 'Income' THEN 0  WHEN debit_account.account_type = 'Income' THEN -1 * amount  WHEN credit_account.account_type = 'Income' THEN amount ELSE 0 END) AS income,
    SUM(CASE WHEN debit_account.account_type = 'Expense' AND credit_account.account_type = 'Expense' THEN 0 WHEN debit_account.account_type = 'Expense' THEN amount  WHEN credit_account.account_type = 'Expense' THEN -1 * amount ELSE 0 END) AS expense,
    SUM(CASE WHEN debit_account.account_type = 'Bank' AND credit_account.account_type = 'Bank' THEN 0  WHEN debit_account.account_type = 'Bank' THEN amount  WHEN credit_account.account_type = 'Bank' THEN -1*amount ELSE 0 END) AS assets,
    SUM(CASE WHEN debit_account.account_type = 'CCard' AND credit_account.account_type = 'CCard' THEN 0 WHEN debit_account.account_type = 'CCard' THEN -1*amount  WHEN credit_account.account_type = 'CCard' THEN amount ELSE 0 END) AS liabilities
    FROM entries 
    LEFT JOIN accounts debit_account ON debit_account_id = debit_account.id 
    LEFT JOIN accounts credit_account ON credit_account_id = credit_account.id
    WHERE entries.date > CURRENT_DATE - '1 year 1 month'::interval
    GROUP BY EXTRACT(YEAR FROM entries.date)::text || to_char(-1*EXTRACT(MONTH FROM entries.date), '00')
    ORDER BY month DESC
    SQL
    @months = Entry.find_by_sql(sql)[0...-1]
  end
  
  def net_worth
    account = Account.find_by_sql("SELECT SUM(CASE WHEN account_type = 'Bank' THEN balance ELSE 0 END) AS assets, -SUM(CASE WHEN account_type = 'CCard' THEN balance ELSE 0 END) AS liabilities FROM accounts")[0]
    @assets, @liabilities = account[:assets].to_f, account[:liabilities].to_f
    income_expense
  end
  
  def earning_spending
      sql =<<-SQL
      SELECT accounts.account_type, accounts.name, #{(0...12).to_a.collect{|i| "\nSUM(CASE WHEN extract(month from 
      age(((CURRENT_DATE + 1) - (extract(day from CURRENT_DATE)::integer)), 
      ((entries.date + 1) - (extract(day from entries.date)::integer)))) != #{i} THEN 0 WHEN debit_account_id = accounts.id THEN amount ELSE -amount END)"}.join(",")}
      FROM accounts 
      LEFT JOIN entries ON debit_account_id = accounts.id OR credit_account_id = accounts.id
      WHERE entries.amount IS NOT NULL AND (accounts.account_type = 'Income' OR accounts.account_type = 'Expense') AND age(((CURRENT_DATE + 1) - (extract(day from CURRENT_DATE)::integer)), ((entries.date + 1) - (extract(day from entries.date)::integer))) < '1 year'::interval
      GROUP BY accounts.account_type, accounts.name
      ORDER BY account_type DESC, name
      SQL
      @accounts = Account.connection.execute(sql)
  end
end
