module ReportsHelper
  def balance_sheet_rows(accounts)
    accounts.collect{|account| "<tr><td class='account_name'>#{h account.name}</td><td class='money'>#{account.money_balance}</td></tr>" }.join("\n").html_safe!
  end
end
