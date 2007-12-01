ActionController::Routing::Routes.draw do |map|
  map.connect '', :controller => "login"
  map.connect ':controller/:action/:id'
end
