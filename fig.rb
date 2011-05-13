#!/usr/bin/env ruby

$LOAD_PATH << 'lib'
$LOAD_PATH << '../lib'

$KCODE = 'u' unless defined? ::Encoding

require 'rubygems'
require 'net/irc'
require 'pit'
require 'facebook_irc_gateway'

CONFIG = Pit.get("facebok_irc_gateway", :require => {
      'id' => 'Application ID',
      'secret' => 'Application Secret',
      'callback' => 'Callback URL',
      'code' => 'Your Authorization Code'
})

if __FILE__ == $0
  require 'optparse'

  opts = {
    :port => 16822,
    :host => 'localhost',
    :log  => nil,
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

      parse!(ARGV)
    end
  end

  opts[:logger] = Logger.new($stdout, 'daily')
  opts[:logger].level = Logger::DEBUG
  opts[:pit] = @pit

  Net::IRC::Server.new(opts[:host], opts[:port], FacebookIrcGateway::Server, opts).start
end

