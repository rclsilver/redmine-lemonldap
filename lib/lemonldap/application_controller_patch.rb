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
        remote_username = request.env['HTTP_AUTH_USER']

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
        try_login remote_username
      end

      def try_login(remote_username)
        # find user by login name
        user = User.active.find_by_login remote_username
      
        if user.nil?
          #user was not found in the database, try selfregistration if enabled
          if Setting.plugin_redmine_lemonldap['auto_registration'] == 'true'

            # fill the new user with values from HTTP headers
            @user = User.new(:language => Setting.default_language)
            @user.login = remote_username
            @user.admin = false # HTTP_IS_ADMIN
            @user.firstname = 'Thomas' # HTTP_FIRSTNAME
            @user.lastname = 'Betrancourt' # HTTP_LASTNAME
            @user.mail = 'thomas@betrancourt.net' # HTTP_EMAIL

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
          #login and return user if user was found
          do_login user
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
