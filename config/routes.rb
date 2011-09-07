Spam::Application.routes.draw do
  root :to => "login#index"
  match ':controller(/:action(/:id(.:format)))'
  match '*a', :to=> "login#render_404"
end
