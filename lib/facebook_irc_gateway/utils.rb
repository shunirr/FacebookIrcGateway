# -*- coding: utf-8 -*-

require 'net/https'
require 'json'
require 'ya2yaml'
Net::HTTP.version_1_2

module FacebookIrcGateway
  class Utils
    def self.shorten_url(url)
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

    ##
    # 発言内容の URL を取得して短くする
    # @param:: +message+ フィード文字列
    def self.url_filter(message)
      message.gsub( URI.regexp(["http", "https"]) ){ |url|
        begin
          u = URI( url )
          http = Net::HTTP.new( u.host )
          response = http.head( u.path )
          next url unless response.code.to_i == 200
          next url if response['content-type'][0..4] == "image"
          shorten_url(url)
        rescue => e
          puts e.inspect
          url
        end
      }
    end
  end
end

class String
  IRC_COLORMAP = {
    :white => 0,
    :black => 1,
    :blue => 2,
    :navy => 2,
    :green => 3,
    :red => 4,
    :brown => 5,
    :maroon => 5,
    :purple => 6,
    :orange => 7,
    :olive => 7,
    :yellow => 8,
    :light_green => 9,
    :lime => 9,
    :teal => 10,
    :blue_cyan => 10,
    :light_cyan => 11,
    :cyan => 11,
    :aqua => 11,
    :light_blue => 12,
    :royal => 12,
    :pink => 13,
    :light_purple => 13,
    :fuchsia => 13,
    :grey => 14,
    :light_grey => 15,
    :silver => 15
  }

  def irc_colorize(options = {})
    color = options[:color]
    color = IRC_COLORMAP[color.to_sym] if color.class == Symbol or color.class == String
    background = options[:background]
    background = IRC_COLORMAP[background.to_sym] if background.class == Symbol  or background.class == String

    return self if color.nil? and background.nil?

    if background.nil?
      return "\x03#{color}#{self}\x03"
    else
      return "\x03#{color},#{background}#{self}\x03"
    end
  end
end

class Object
  def fig_ya2yaml(options = {})
    ya2yaml(options).gsub(/^\?\s*/, '').gsub(/\n\s*:/, ':')
  end
end

