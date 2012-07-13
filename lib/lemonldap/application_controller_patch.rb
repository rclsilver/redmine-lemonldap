module LemonLDAP
  module Patches
    module ApplicationControllerPatch
      def self.included(base) # :nodoc:
        base.send(:include, ClassMethods)
        base.class_eval do
          #avoid infinite recursion in development mode on subsequent requests
          alias_method :find_current_user, :find_current_user_without_lemonldap if method_defined? 'find_current_user_without_lemonldap'

          #chain our version of find_current_user implementation into redmine core
          alias_method_chain(:find_current_user, :lemonldap)
        end
      end
    end

    module ClassMethods
      def find_current_user_with_lemonldap
        #first proceed with redmine's version of finding current user
        user = find_current_user_without_lemonldap

        #if the LemonLDAP authentication is disabled in config, return the user
        return user unless Setting.plugin_redmine_lemonldap['enable'] == "true"

        # fetch the username from the HTTP header
        remote_username = request.env[Setting.plugin_redmine_lemonldap['username_env_var']]

        if remote_username.nil?
          # do not touch user, if he didn't use http authentication to log in
          if !used_lemonldap_authentication?
            return user
          end

          #log out previously authenticated user
          reset_session
          return nil
        end

        #return if the user has not been changed behind the session
        return user unless session_changed? user, remote_username

        #log out current logged in user
        reset_session
        try_login remote_username, request
      end

      def try_login(remote_username, request)
        # find user by login name
        user = User.active.find_by_login remote_username
      
        if user.nil?
          #user was not found in the database, try selfregistration if enabled
          if Setting.plugin_redmine_lemonldap['auto_registration'] == 'true'
            # get HTTP header names
            user_firstname_attr = Setting.plugin_redmine_lemonldap['firstname_env_var']
            user_lastname_attr = Setting.plugin_redmine_lemonldap['lastname_env_var']
            user_email_attr = Setting.plugin_redmine_lemonldap['email_env_var']
            user_isadmin_attr = Setting.plugin_redmine_lemonldap['isadmin_env_var']

            # initialize values
            user_firstname = '<no first name given>'
            user_lastname = '<no last name given>'
            user_email = 'no-mail-given@example.com'
            user_isadmin = false

            # set values if available
            if !user_firstname_attr.nil? and !user_firstname_attr.empty?
              if request.env.has_key?(user_firstname_attr) and !request.env[user_firstname_attr].nil? and !request.env[user_firstname_attr].empty?
                user_firstname = request.env[user_firstname_attr]
              end
            end

            if !user_lastname_attr.nil? and !user_lastname_attr.empty?
              if request.env.has_key?(user_lastname_attr) and !request.env[user_lastname_attr].nil? and !request.env[user_lastname_attr].empty?
                user_lastname = request.env[user_lastname_attr]
              end
            end

            if !user_email_attr.nil? and !user_email_attr.empty?
              if request.env.has_key?(user_email_attr) and !request.env[user_email_attr].nil? and !request.env[user_email_attr].empty?
                user_email = request.env[user_email_attr]
              end
            end

            if !user_isadmin_attr.nil? and !user_isadmin_attr.empty?
              if request.env.has_key?(user_isadmin_attr) and !request.env[user_isadmin_attr].nil? and !request.env[user_isadmin_attr].empty?
                user_isadmin = request.env[user_isadmin_attr]
              end
            end

            # fill the new user with values from HTTP headers
            @user = User.new(:language => Setting.default_language)
            @user.login = remote_username
            @user.firstname = user_firstname
            @user.lastname = user_lastname
            @user.mail = user_email
            @user.admin = user_isadmin == 'true'

            if @user.save
              return @user
            else
              flash[:error] = l :error_cannot_create_user
              return nil
            end
          else
            flash[:error] = l :error_unknown_user
            return nil
          end
        else
          # update the user if properties has changed
          user_firstname_attr = Setting.plugin_redmine_lemonldap['firstname_env_var']
          user_lastname_attr = Setting.plugin_redmine_lemonldap['lastname_env_var']
          user_email_attr = Setting.plugin_redmine_lemonldap['email_env_var']
          user_isadmin_attr = Setting.plugin_redmine_lemonldap['isadmin_env_var']

          user_firstname = nil
          user_lastname = nil
          user_email = nil
          user_isadmin = nil

          has_changed = false

          if !user_firstname_attr.nil? and !user_firstname_attr.empty?
            if request.env.has_key?(user_firstname_attr) and !request.env[user_firstname_attr].nil? and !request.env[user_firstname_attr].empty?
              user_firstname = request.env[user_firstname_attr]
            end
          end

          if !user_lastname_attr.nil? and !user_lastname_attr.empty?
            if request.env.has_key?(user_lastname_attr) and !request.env[user_lastname_attr].nil? and !request.env[user_lastname_attr].empty?
              user_lastname = request.env[user_lastname_attr]
            end
          end

          if !user_email_attr.nil? and !user_email_attr.empty?
            if request.env.has_key?(user_email_attr) and !request.env[user_email_attr].nil? and !request.env[user_email_attr].empty?
              user_email = request.env[user_email_attr]
            end
          end

          if !user_isadmin_attr.nil? and !user_isadmin_attr.empty?
            if request.env.has_key?(user_isadmin_attr) and !request.env[user_isadmin_attr].nil? and !request.env[user_isadmin_attr].empty?
              user_isadmin = request.env[user_isadmin_attr]
            end
          end

          if !user_firstname.nil? && user.firstname != user_firstname
            user.firstname = user_firstname
            has_changed = true
          end

          if !user_lastname.nil? && user.lastname != user_lastname
            user.lastname = user_lastname
            has_changed = true
          end

          if !user_email.nil? && user.mail != user_email
            user.mail = user_email
            has_changed = true
          end

          if !user_isadmin.nil? && user.admin != (user_isadmin == 'true')
            user.admin = user_isadmin == 'true'
            has_changed = true
          end

          has_error = false

          if has_changed
            if !user.save
              has_error = true
            end
          end

          # login and return user
          do_login user

          if has_changed
            if has_error
              flash[:error] = l :error_cannot_update_user
            else
              flash[:notice] = l :info_user_updated
            end
          end

          return user
        end
      end

      def used_lemonldap_authentication?
        session[:lemonldap_authentication] == true
      end

      def session_changed?(user, remote_username)
        if user.nil?
          true
        else
          user.login.casecmp(remote_username) != 0
        end
      end

      def do_login(user)
        if (user && user.is_a?(User))
          session[:user_id] = user.id
          session[:lemonldap_authentication] = true
          user.update_attribute(:last_login_on, Time.now)
          User.current = user
        else
          return nil
        end
      end
    end
  end
end

unless ApplicationController.included_modules.include? LemonLDAP::Patches::ApplicationControllerPatch
  ApplicationController.send(:include, LemonLDAP::Patches::ApplicationControllerPatch)
end
