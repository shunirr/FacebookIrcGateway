#!/usr/bin/env ruby

$LOAD_PATH << 'lib'
$KCODE = 'u' unless defined? ::Encoding

require 'rubygems'
require 'net/irc'
require 'pit'
require 'optparse'
require 'yaml'

require 'facebook_irc_gateway'

pit = Pit.get("facebook_irc_gateway", :require => {
  'id'       => 'Application ID',
  'secret'   => 'Application Secret',
  'callback' => 'Callback URL',
  'code'     => 'Your Authorization Code'
})

config_path = 'config.yaml'

OptionParser.new do |parser|
  parser.instance_eval do
    self.banner  = <<-EOB.gsub(/^\t+/, '')
      Usage: #{$0} [opts]

    EOB

    separator ''

    separator 'Options:'
    on('-c', "--config [CONFIG=#{config_path}]", 'path to config.yaml') do |path|
      config_path = path
    end

    parse!(ARGV)
  end
end

begin
  opts = YAML::load_file(config_path)
rescue Exception => e
#  puts 'Fail to load config file...'
#  exit -1
end

opts = {} if opts.class != Hash.class
opts[:host]       = '127.0.0.1'     if opts[:host].nil?
opts[:port]       = 16822           if opts[:port].nil?
opts[:userlist]   = 'userlist.yaml' if opts[:userlist].nil?
opts[:app_id]     = pit['id']
opts[:app_secret] = pit['secret']
opts[:callback]   = pit['callback']
opts[:code]       = pit['code']
opts[:logger]     = Logger.new($stdout, 'daily')
opts[:logger].level = Logger::DEBUG

Net::IRC::Server.new(opts[:host], opts[:port], FacebookIrcGateway::Server, opts).start

