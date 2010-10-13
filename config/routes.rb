Spam::Application.routes.draw do
  root :to => "login#index"
  match ':controller(/:action(/:id(.:format)))'
end
