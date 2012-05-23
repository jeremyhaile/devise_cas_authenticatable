module DeviseCasAuthenticatable
  module SingleSignOut

    def self.rails3?
      defined?(::Rails) && ::Rails::VERSION::MAJOR == 3
    end

    # Supports destroying sessions by ID for ActiveRecord and Redis session stores
    module DestroySession
      def session_store_class
        @session_store_class ||=
          begin
            if ::DeviseCasAuthenticatable::SingleSignOut.rails3?
              # => Rails 3
              ::Rails.application.config.session_store
            else
              # => Rails 2
              ActionController::Base.session_store
            end
          rescue NameError => e
            # for older versions of Rails (prior to 2.3)
            ActionController::Base.session_options[:database_manager]
          end
      end

      def current_session_store
        app = get_first_middleware_app
        begin
          app = app.instance_variable_get :@app
        end until app.nil? or app.class == session_store_class
        app
      end

      def destroy_session_by_id(sid)
        if session_store_class == ActiveRecord::SessionStore
          session = current_session_store::Session.find_by_session_id(sid)
          session.destroy if session
          true
        elsif session_store_class.name =~ /Redis.*Store/
          current_session_store.instance_variable_get(:@pool).del(sid)
          true
        else
          ::Rails.logger.error "Cannot process logout request because this Rails application's session store is "+
                " #{current_session_store.class.to_s} and is not a support session store type for Single Sign-Out."
          false
        end
      end
      
      private
      
      def get_first_middleware_app
        # For case of running in production mode.
        @first_middleware_app ||= if defined?(Rack::Cache::Context) && Rails.application.app.class == Rack::Cache::Context
                                    Rails.application.app.
                                      entitystore.instance_variable_get(:@store).
                                      instance_variable_get(:@middleware).instance_variable_get(:@app)
                                  else
                                    Rails.application.app
                                  end
                                  
      end
    end

  end
end

require 'devise_cas_authenticatable/single_sign_out/strategies'
require 'devise_cas_authenticatable/single_sign_out/strategies/base'
require 'devise_cas_authenticatable/single_sign_out/strategies/rails_cache'
require 'devise_cas_authenticatable/single_sign_out/rack'
