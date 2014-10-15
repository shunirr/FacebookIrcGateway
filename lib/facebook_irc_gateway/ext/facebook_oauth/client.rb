module FacebookOAuth
  class Client
    def authorize_url(options = {})
      default_options = {
        :client_id => @application_id,
        :redirect_uri => @callback,
        :scope => 'offline_access,publish_stream',
      }
      client.auth_code.authorize_url default_options.merge(options)
    end

    private

    def client
      @client ||= OAuth2::Client.new(@application_id, @application_secret, {
        site: 'https://graph.facebook.com',
        token_url: '/oauth/access_token',
        connection_opts: {
          ssl: {
            version: 'TLSv1'
          }
        }
      })
    end
  end
end
