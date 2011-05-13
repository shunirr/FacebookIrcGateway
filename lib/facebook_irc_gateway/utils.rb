
require 'net/https'
require 'json'
Net::HTTP.version_1_2

module FacebookIrcGateway
  class Utils
    def shorten_url(url)
      # already shoten
      return url if url.size < 20
  
      api = URI.parse 'https://www.googleapis.com/urlshortener/v1/url'
  
      https = Net::HTTP.new(api.host, api.port)
      https.use_ssl = true
      https.verify_mode = OpenSSL::SSL::VERIFY_NONE
      https.start {|http|
        header = {"Content-Type" => "application/json"}
        body   = {'longUrl' => url}.to_json
        response = http.post(api.path, body, header)
        json = JSON.parse(response.body)
        short = json['id']
  
        return short if short and short.size > 14
      }
  
      return url
    end
  end
end
