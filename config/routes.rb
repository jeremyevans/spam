Spam::Application.routes.draw do
  root :to => "login#index"
  match ':controller(/:action(/:id(.:format)))', :via=>[:get, :post]
  match '*a', :to=> "login#render_404", :via=>[:get, :post]
end
