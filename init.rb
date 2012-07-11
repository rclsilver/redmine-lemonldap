Redmine::Plugin.register :redmine_lemonldap do
  name 'LemonLDAP::NG plugin'
  author 'Thomas Bétrancourt'
  description 'Allow users to log in to your site using LemonLDAP::NG authentication'
  version '0.0.1'
  url 'http://projects.rclsilver.net/projects/redmine-lemonldap'
  author_url 'http://www.betrancourt.net/thomas'
  settings :partial => 'settings/redmine_lemonldap_settings',
           :default => {
             'enable' => 'false',
             'username_env_var' => 'HTTP_AUTH_USER',
             'firstname_env_var' => 'HTTP_FIRSTNAME',
             'lastname_env_var' => 'HTTP_LASTNAME',
             'email_env_var' => 'HTTP_EMAIL',
             'isadmin_env_var' => 'HTTP_IS_ADMIN',
             'auto_registration' => 'false'
           }
end
