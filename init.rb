Redmine::Plugin.register :redmine_lemonldap do
  name 'LemonLDAP::NG plugin'
  author 'Thomas Betrancourt'
  description 'Allow users to log in to your site using LemonLDAP::NG authentication'
  version '0.0.1'
  url 'http://projects.rclsilver.net/projects/redmine-lemonldap'
  author_url 'http://www.betrancourt.net/thomas'
  settings :partial => 'settings/redmine_lemonldap_settings',
           :default => {
             'enable' => 'false',
             'portal_url' => nil,
             'username_env_var' => 'HTTP_AUTH_USER',
             'firstname_env_var' => 'HTTP_FIRSTNAME',
             'lastname_env_var' => 'HTTP_LASTNAME',
             'email_env_var' => 'HTTP_EMAIL',
             'isadmin_env_var' => 'HTTP_IS_ADMIN',
             'auto_registration' => 'false'
           }
end

ActionDispatch::Callbacks.to_prepare do
  require 'lemonldap/application_controller_patch'
end

Redmine::MenuManager.map :account_menu do |menu|
    menu.push :login_lemonldap, 
              { :controller => 'lemonldap', :action => 'portal_login' }, 
              :before => :login, 
              :caption => :login_lemonldap_title,
              :if => Proc.new { User.current.anonymous? && Setting.plugin_redmine_lemonldap['enable'] == 'true' && !Setting.plugin_redmine_lemonldap['portal_url'].nil? && !Setting.plugin_redmine_lemonldap['portal_url'].empty? }
end
