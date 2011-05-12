#!/usr/bin/env ruby
# vim:encoding=UTF-8:

$LOAD_PATH << "lib"
$LOAD_PATH << "../lib"

$KCODE = "u" unless defined? ::Encoding

require "rubygems"
require "net/irc"
require "sdbm"
require "tmpdir"
require "uri"
require 'oauth'
require 'facebook_oauth'
require 'yaml'


class FacebookIrcGateway < Net::IRC::Server::Session
  def server_name
    "fig"
  end

  def server_version
    "0.0.0"
  end

  def main_channel
    "#facebook"
  end

  def initialize(*args)
    super
    config = YAML::load(open('config.yaml').read)
    agent = FacebookOAuth::Client.new(
      :application_id     => config['app']['id'],
      :application_secret => config['app']['secret'],
      :callback           => config['app']['callback']
    )
    access_token = agent.authorize(:code => config['client']['code'])
    @client = FacebookOAuth::Client.new(
      :application_id     => config['app']['id'],
      :application_secret => config['app']['secret'],
      :token              => access_token.token
    )
  end

  def on_user(m)
    super
    post @prefix, JOIN, main_channel
    post server_name, MODE, main_channel, "+o", @prefix.nick

    @real, *@opts = @opts.name || @real.split(/\s+/)
    @opts = @opts.inject({}) {|r,i|
      key, value = i.split("=")
      r.update(key => value)
    }

    @timeline = []
    @check_friends_thread = Thread.start do
      loop do
        begin
          check_friends
        rescue ApiFailed => e
          @log.error e.inspect
        rescue Exception => e
          @log.error e.inspect
          e.backtrace.each do |l|
            @log.error "\t#{l}"
          end
        end
        sleep freq(@ratio[:friends] / @footing)
      end
    end

    @check_timeline_thread = Thread.start do
      sleep 3
      loop do
        begin
          check_timeline
        rescue ApiFailed => e
          @log.error e.inspect
        rescue Exception => e
          @log.error e.inspect
          e.backtrace.each do |l|
            @log.error "\t#{l}"
          end
        end
        sleep 60
      end
    end
  end

  def on_disconnected
    @observer.kill rescue nil
  end

  def on_privmsg(m)
    super
    @client.me.feed(:create, :message => m[1])
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
    friends = @client.me.friends['data'].map{|i| {'name' => i['name'].gsub(/\s+/,''), 'id' => i['id']} }

    if first && !@opts.key?("athack")
      @friends = friends
      post server_name, RPL_NAMREPLY,   @nick, "=", main_channel, @friends.map{|i| "@#{i["name"]}" }.join(" ")
      post server_name, RPL_ENDOFNAMES, @nick, main_channel, "End of NAMES list"
    else
      prv_friends = @friends.map {|i| i["name"] }
      now_friends = friends.map {|i| i["name"] }

      (now_friends - prv_friends).each do |join|
        join = "@#{join}" if @opts.key?("athack")
        post "#{join}!#{join}@#{api_base.host}", JOIN, main_channel
      end
      (prv_friends - now_friends).each do |part|
        part = "@#{part}" if @opts.key?("athack")
        post "#{part}!#{part}@#{api_base.host}", PART, main_channel, ""
      end
      @friends = friends
    end
  end


  def check_timeline
    begin
      db = SDBM.open("#{Dir.tmpdir}/#{@real}.db", 0666)
      @client.me.home['data'].reverse.each do |d|
        id = d['id']
        if db.include?(id)
          next
        else
          db[id] = "1"
        end
        post d['from']['name'].gsub(/\s+/, ''), PRIVMSG, main_channel, "#{d['message']}"
      end
    rescue Exception => e
      @log.error e.inspect
    ensure
      db.close rescue nil
    end
    sleep 60
  end
end

if __FILE__ == $0
  require "optparse"

  opts = {
  :port       => 16822,
  :host       => "localhost",
  :log        => nil,
  :debug      => false,
  :foreground => false,
  }

  OptionParser.new do |parser|
    parser.instance_eval do
      self.banner  = <<-EOB.gsub(/^\t+/, "")
        Usage: #{$0} [opts]

      EOB

      separator ""

      separator "Options:"
      on("-p", "--port [PORT=#{opts[:port]}]", "port number to listen") do |port|
        opts[:port] = port
      end

      on("-h", "--host [HOST=#{opts[:host]}]", "host name or IP address to listen") do |host|
        opts[:host] = host
      end

      on("-l", "--log LOG", "log file") do |log|
        opts[:log] = log
      end

      on("--debug", "Enable debug mode") do |debug|
        opts[:log]   = $stdout
        opts[:debug] = true
      end

      on("-f", "--foreground", "run foreground") do |foreground|
        opts[:log]        = $stdout
        opts[:foreground] = true
      end

      parse!(ARGV)
    end
  end

  opts[:logger] = Logger.new(opts[:log], "daily")
  opts[:logger].level = opts[:debug] ? Logger::DEBUG : Logger::INFO

 def daemonize(foreground=false)
    trap("SIGINT")  { exit! 0 }
    trap("SIGTERM") { exit! 0 }
    trap("SIGHUP")  { exit! 0 }
    return yield if $DEBUG || foreground
    Process.fork do
      Process.setsid
      Dir.chdir "/"
      File.open("/dev/null") {|f|
        STDIN.reopen  f
        STDOUT.reopen f
        STDERR.reopen f
      }
      yield
    end
    exit! 0
  end

  daemonize(opts[:debug] || opts[:foreground]) do
    Net::IRC::Server.new(opts[:host], opts[:port], FacebookIrcGateway, opts).start
  end
end

# Local Variables:
# coding: utf-8
# End:
