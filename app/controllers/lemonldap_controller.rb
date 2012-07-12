class LemonldapController < ApplicationController
  unloadable

  def portal_login
    param_url = nil

    if request.headers.include?('HTTP_REFERER')
      param_url = request.headers['HTTP_REFERER']
    end

    if param_url.nil? || param_url.empty?
      param_url = home_url
    end

    param_url = Base64.encode64(param_url).strip

    url = nil

    if Setting.plugin_redmine_lemonldap['enable'] == 'true'
      url = Setting.plugin_redmine_lemonldap['portal_url']
    end

    if !url.nil? && !url.empty?
      url = "#{url}?url=#{param_url}"
      redirect_to url
    else
      redirect_to home_url
    end
  end
end
