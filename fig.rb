#!/usr/bin/env ruby
# vim:encoding=UTF-8:

$LOAD_PATH << 'lib'
$LOAD_PATH << '../lib'

$KCODE = 'u' unless defined? ::Encoding

require 'rubygems'
require 'net/irc'
require 'sdbm'
require 'tmpdir'
require 'uri'
require 'oauth'
require 'facebook_oauth'
require 'pit'
require 'openssl'
require 'open-uri'

OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

CONFIG = Pit.get("facebok_irc_gateway", :require => {
      'id' => 'Application ID',
      'secret' => 'Application Secret',
      'callback' => 'Callback URL',
      'code' => 'Your Authorization Code'
})

class FacebookIrcGateway < Net::IRC::Server::Session
  def server_name
    'FacebookIrcGateway'
  end

  def server_version
    '0.0.0'
  end

  def main_channel
    '#facebook'
  end

  def initialize(*args)
    super
    
    # read config file
    config = {'app' => {'id' => CONFIG['id'], 'secret' => CONFIG['secret'], 'callback' => CONFIG['callback']}, 'client' => {'code' => CONFIG['code']}}

    begin
      agent = FacebookOAuth::Client.new(
        :application_id     => config['app']['id'],
        :application_secret => config['app']['secret'],
        :callback           => config['app']['callback']
      )
    rescue Exception => e
      @log.error e.inspect
      e.backtrace.each do |l|
        @log.error "\t#{l}"
      end
    end

    # got oauth client code?
    @setup = config['client']['code'].nil?

    if @setup then
      @client = agent
      return
    end

    begin
      @access_token = agent.authorize(:code => config['client']['code'])
      @client = FacebookOAuth::Client.new(
        :application_id     => config['app']['id'],
        :application_secret => config['app']['secret'],
        :token              => @access_token.token
      )

      @myid = @client.me.feed['data'][0]['from']['id'].to_i
      @log.debug "my id: #{@myid}"
    rescue Exception => e
      @log.error e.inspect
      e.backtrace.each do |l|
        @log.error "\t#{l}"
      end
    end
  end

  def on_user(m)
    super
    post @prefix, JOIN, main_channel
    post server_name, MODE, main_channel, '+o', @prefix.nick

    @real, *@opts = @opts.name || @real.split(/\s+/)
    @opts = @opts.inject({}) {|r,i|
      key, value = i.split('=')
      r.update(key => value)
    }

    @timeline = []
    @check_friends_thread = Thread.start do
#      loop do
        begin
          check_friends
        rescue Exception => e
          @log.error e.inspect
          e.backtrace.each do |l|
            @log.error "\t#{l}"
          end
        end
#        sleep freq(@ratio[:friends] / @footing)
#      end
    end

    @check_news_thread = Thread.start do
      sleep 3
      while true
        begin
          check_news
        rescue Exception => e
          @log.error e.inspect
          e.backtrace.each do |l|
            @log.error "\t#{l}"
          end
        end
        sleep 20
      end
    end
  end

  def on_disconnected
    @observer.kill rescue nil
  end

  def on_privmsg(m)
    super
    begin
      ret = @client.me.feed(:create, :message => m[1])
      post server_name, NOTICE, main_channel, "#{m[1]} (#{ret.to_s})"
    rescue Exception => e
      post server_name, NOTICE, main_channel, 'Fail Update...'
      @log.error e.inspect
      e.backtrace.each do |l|
        @log.error "\t#{l}"
      end
    end
  end

  def on_ctcp(target, message)
  end

  def on_whois(m)
  end

  def on_who(m)
  end

  def on_join(m)
  end

  def on_part(m)
  end

  private
  def check_friends
    first = true unless @friends
    @friends ||= []
    friends = @client.me.friends['data'].map do |i|
      {
        'name' => i['name'].gsub(/\s+/,''), 
        'id'   => i['id'].to_i
      }
    end

    if first
      @friends = friends
      post server_name, RPL_NAMREPLY,   @nick, '=', main_channel, @friends.map{|i| "@#{i['name']}" }.join(' ')
      post server_name, RPL_ENDOFNAMES, @nick, main_channel, 'End of NAMES list'
    else
      prv_friends = @friends.map {|i| i['name'] }
      now_friends =  friends.map {|i| i['name'] }

      (now_friends - prv_friends).each do |join|
        join = "@#{join}"
        post "#{join}!#{join}@#{api_base.host}", JOIN, main_channel
      end

      (prv_friends - now_friends).each do |part|
        part = "@#{part}"
        post "#{part}!#{part}@#{api_base.host}", PART, main_channel, ''
      end
      @friends = friends
    end
  end

  def check_news
    begin
      db = SDBM.open("#{Dir.tmpdir}/#{@real}_news.db", 0666)
      @client.me.home['data'].reverse.each do |d|
        id          = d['id']
        message     = d['message']
        app_name    = d['application']['name'] if d['application']
        name        = d['from']['name'].gsub(/\s+/, '')
        link        = d['link']
        caption     = d['caption']
        description = d['description']
        comments    = d['comments']['data'] if d['comments']
        #likes       = d['likes']['data'] if d['likes']

        message = '' unless message
        name = server_name unless name

        unless db.include?(id)
          db[id] = '1'

          mes = "#{message} "
          if caption
            if mes != ''
              mes += '/ '
            end
            mes += "#{caption} "
          end

          if description
            if mes != ''
              mes += '/ '
            end
            mes += "#{description} "
          end

          mes += " #{link} " if link

          if app_name
            mes += "(#{app_name}) "
          else
            mes += '(web) '
          end

          post name, PRIVMSG, main_channel, mes
        end

        comments.each do |comment|
          cid   = comment['id']
          cname = comment['from']['name'].gsub(/\s+/, '')
          unless db.include?(cid)
            db[cid] = '1'
            post cname, PRIVMSG, main_channel, "#{comment['message']} >> #{name}: #{message}"
          end
        end if comments

      end
    rescue Exception => e
      @log.error e.inspect
    ensure
      db.close rescue nil
    end
  end
end

if __FILE__ == $0
  require 'optparse'

  opts = {
    :port => 16822,
    :host => 'localhost',
    :log  => nil,
    :config => 'config.yaml',
  }

  OptionParser.new do |parser|
    parser.instance_eval do
      self.banner  = <<-EOB.gsub(/^\t+/, '')
        Usage: #{$0} [opts]

      EOB

      separator ''

      separator 'Options:'
      on('-p', "--port [PORT=#{opts[:port]}]", 'port number to listen') do |port|
        opts[:port] = port
      end

      on('-h', "--host [HOST=#{opts[:host]}]", 'host name or IP address to listen') do |host|
        opts[:host] = host
      end

      on('-l', '--log LOG', 'log file') do |log|
        opts[:log] = log
      end

      on('-c', "--config [CONF=#{opts[:config]}", 'config file') do |config|
        opts[:config] = config
      end

      parse!(ARGV)
    end
  end

  opts[:logger] = Logger.new($stdout, 'daily')
  opts[:logger].level = Logger::DEBUG
  opts[:pit] = @pit

  Net::IRC::Server.new(opts[:host], opts[:port], FacebookIrcGateway, opts).start
end

# Local Variables:
# coding: utf-8
# End:
