module ActionController
  # In <b>routes.rb</b> one defines URL-to-controller mappings, but the reverse
  # is also possible: an URL can be generated from one of your routing definitions.
  # URL generation functionality is centralized in this module.
  #
  # See ActionController::Routing and ActionController::Resources for general
  # information about routing and routes.rb.
  #
  # <b>Tip:</b> If you need to generate URLs from your models or some other place,
  # then ActionController::UrlWriter is what you're looking for. Read on for
  # an introduction.
  #
  # == URL generation from parameters
  #
  # As you may know, some functions - such as ActionController::Base#url_for
  # and ActionView::Helpers::UrlHelper#link_to, can generate URLs given a set
  # of parameters. For example, you've probably had the chance to write code
  # like this in one of your views:
  #
  #   <%= link_to('Click here', :controller => 'users',
  #           :action => 'new', :message => 'Welcome!') %>
  #
  #   #=> Generates a link to: /users/new?message=Welcome%21
  #
  # link_to, and all other functions that require URL generation functionality,
  # actually use ActionController::UrlWriter under the hood. And in particular,
  # they use the ActionController::UrlWriter#url_for method. One can generate
  # the same path as the above example by using the following code:
  #
  #   include UrlWriter
  #   url_for(:controller => 'users',
  #           :action => 'new',
  #           :message => 'Welcome!',
  #           :only_path => true)
  #   # => "/users/new?message=Welcome%21"
  #
  # Notice the <tt>:only_path => true</tt> part. This is because UrlWriter has no
  # information about the website hostname that your Rails app is serving. So if you
  # want to include the hostname as well, then you must also pass the <tt>:host</tt>
  # argument:
  #
  #   include UrlWriter
  #   url_for(:controller => 'users',
  #           :action => 'new',
  #           :message => 'Welcome!',
  #           :host => 'www.example.com')        # Changed this.
  #   # => "http://www.example.com/users/new?message=Welcome%21"
  #
  # By default, all controllers and views have access to a special version of url_for,
  # that already knows what the current hostname is. So if you use url_for in your
  # controllers or your views, then you don't need to explicitly pass the <tt>:host</tt>
  # argument.
  #
  # For convenience reasons, mailers provide a shortcut for ActionController::UrlWriter#url_for.
  # So within mailers, you only have to type 'url_for' instead of 'ActionController::UrlWriter#url_for'
  # in full. However, mailers don't have hostname information, and what's why you'll still
  # have to specify the <tt>:host</tt> argument when generating URLs in mailers.
  #
  #
  # == URL generation for named routes
  #
  # UrlWriter also allows one to access methods that have been auto-generated from
  # named routes. For example, suppose that you have a 'users' resource in your
  # <b>routes.rb</b>:
  #
  #   map.resources :users
  #
  # This generates, among other things, the method <tt>users_path</tt>. By default,
  # this method is accessible from your controllers, views and mailers. If you need
  # to access this auto-generated method from other places (such as a model), then
  # you can do that by including ActionController::UrlWriter in your class:
  #
  #   class User < ActiveRecord::Base
  #     include ActionController::UrlWriter
  #
  #     def base_uri
  #       user_path(self)
  #     end
  #   end
  #
  #   User.find(1).base_uri # => "/users/1"
  module UrlWriter
    def self.included(base) #:nodoc:
      ActionController::Routing::Routes.install_helpers(base)
      base.mattr_accessor :default_url_options

      # The default options for urls written by this writer. Typically a <tt>:host</tt> pair is provided.
      base.default_url_options ||= {}
    end

    # Generate a url based on the options provided, default_url_options and the
    # routes defined in routes.rb.  The following options are supported:
    #
    # * <tt>:only_path</tt> - If true, the relative url is returned. Defaults to +false+.
    # * <tt>:protocol</tt> - The protocol to connect to. Defaults to 'http'.
    # * <tt>:host</tt> - Specifies the host the link should be targeted at.
    #   If <tt>:only_path</tt> is false, this option must be
    #   provided either explicitly, or via +default_url_options+.
    # * <tt>:port</tt> - Optionally specify the port to connect to.
    # * <tt>:anchor</tt> - An anchor name to be appended to the path.
    # * <tt>:skip_relative_url_root</tt> - If true, the url is not constructed using the
    #   +relative_url_root+ set in ActionController::Base.relative_url_root.
    # * <tt>:trailing_slash</tt> - If true, adds a trailing slash, as in "/archive/2009/"
    #
    # Any other key (<tt>:controller</tt>, <tt>:action</tt>, etc.) given to
    # +url_for+ is forwarded to the Routes module.
    #
    # Examples:
    #
    #    url_for :controller => 'tasks', :action => 'testing', :host=>'somehost.org', :port=>'8080'    # => 'http://somehost.org:8080/tasks/testing'
    #    url_for :controller => 'tasks', :action => 'testing', :host=>'somehost.org', :anchor => 'ok', :only_path => true    # => '/tasks/testing#ok'
    #    url_for :controller => 'tasks', :action => 'testing', :trailing_slash=>true  # => 'http://somehost.org/tasks/testing/'
    #    url_for :controller => 'tasks', :action => 'testing', :host=>'somehost.org', :number => '33'  # => 'http://somehost.org/tasks/testing?number=33'
    def url_for(options)
      options = self.class.default_url_options.merge(options)

      url = ''

      unless options.delete(:only_path)
        url << (options.delete(:protocol) || 'http')
        url << '://' unless url.match("://")

        raise "Missing host to link to! Please provide :host parameter or set default_url_options[:host]" unless options[:host]

        url << options.delete(:host)
        url << ":#{options.delete(:port)}" if options.key?(:port)
      else
        # Delete the unused options to prevent their appearance in the query string.
        [:protocol, :host, :port, :skip_relative_url_root].each { |k| options.delete(k) }
      end
      trailing_slash = options.delete(:trailing_slash) if options.key?(:trailing_slash)
      url << ActionController::Base.relative_url_root.to_s unless options[:skip_relative_url_root]
      anchor = "##{CGI.escape options.delete(:anchor).to_param.to_s}" if options[:anchor]
      generated = Routing::Routes.generate(options, {})
      url << (trailing_slash ? generated.sub(/\?|\z/) { "/" + $& } : generated)
      url << anchor if anchor

      url
    end
  end

  # Rewrites URLs for Base.redirect_to and Base.url_for in the controller.
  class UrlRewriter #:nodoc:
    RESERVED_OPTIONS = [:anchor, :params, :only_path, :host, :protocol, :port, :trailing_slash, :skip_relative_url_root]
    def initialize(request, parameters)
      @request, @parameters = request, parameters
    end

    def rewrite(options = {})
      rewrite_url(options)
    end

    def to_str
      "#{@request.protocol}, #{@request.host_with_port}, #{@request.path}, #{@parameters[:controller]}, #{@parameters[:action]}, #{@request.parameters.inspect}"
    end

    alias_method :to_s, :to_str

    private
      # Given a path and options, returns a rewritten URL string
      def rewrite_url(options)
        rewritten_url = ""

        unless options[:only_path]
          rewritten_url << (options[:protocol] || @request.protocol)
          rewritten_url << "://" unless rewritten_url.match("://")
          rewritten_url << rewrite_authentication(options)
          rewritten_url << (options[:host] || @request.host_with_port)
          rewritten_url << ":#{options.delete(:port)}" if options.key?(:port)
        end

        path = rewrite_path(options)
        rewritten_url << ActionController::Base.relative_url_root.to_s unless options[:skip_relative_url_root]
        rewritten_url << (options[:trailing_slash] ? path.sub(/\?|\z/) { "/" + $& } : path)
        rewritten_url << "##{CGI.escape(options[:anchor].to_param.to_s)}" if options[:anchor]

        rewritten_url
      end

      # Given a Hash of options, generates a route
      def rewrite_path(options)
        options = options.symbolize_keys
        options.update(options[:params].symbolize_keys) if options[:params]

        if (overwrite = options.delete(:overwrite_params))
          options.update(@parameters.symbolize_keys)
          options.update(overwrite.symbolize_keys)
        end

        RESERVED_OPTIONS.each { |k| options.delete(k) }

        # Generates the query string, too
        Routing::Routes.generate(options, @request.symbolized_path_parameters)
      end

      def rewrite_authentication(options)
        if options[:user] && options[:password]
          "#{CGI.escape(options.delete(:user))}:#{CGI.escape(options.delete(:password))}@"
        else
          ""
        end
      end
  end
end
