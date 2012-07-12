RedmineApp::Application.routes.draw do
  get 'lemonldap_login', :to => 'lemonldap#portal_login'
end
