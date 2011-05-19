#!/usr/bin/env ruby

$LOAD_PATH << (RUBY_VERSION > '1.9' ? './lib' : 'lib')
$KCODE = 'u' unless defined? ::Encoding

require 'rubygems'
require 'bundler'
Bundler.require

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

$opts = {}
begin
  YAML::load_file(config_path).each do |k, v|
    if k == 'color'
      $opts[k.to_sym] = {}
      v.each do |kk,vv|
        $opts[k.to_sym][kk.to_sym] = vv.to_sym
      end
    else
      $opts[k.to_sym] = v
    end
  end
rescue Exception => e
#  puts 'Fail to load config file...'
#  exit -1
end

$opts[:host]          = '127.0.0.1'     if $opts[:host].nil?
$opts[:port]          = 16822           if $opts[:port].nil?
$opts[:userlist]      = 'userlist.yaml' if $opts[:userlist].nil?
$opts[:autoliker]     = false           if $opts[:autoliker].nil?
$opts[:color]         = {}              if $opts[:color].nil?
$opts[:color][:tid]   = :teal           if $opts[:color][:tid].nil?
$opts[:color][:app_name] = :teal        if $opts[:color][:app_name].nil?
$opts[:color][:like]  = :teal           if $opts[:color][:like].nil?
$opts[:color][:parent_message]  = :grey if $opts[:color][:parent_message].nil?
$opts[:db]            = {}              if $opts[:db].nil?
$opts[:db][:adapter]  = 'sqlite3'       if $opts[:db][:adapter].nil?
$opts[:db][:database] = 'data.sqlite'   if $opts[:db][:database].nil?
$opts[:suffix]        = ''              if $opts[:suffix].nil?
$opts[:app_id]        = pit['id']
$opts[:app_secret]    = pit['secret']
$opts[:callback]      = pit['callback']
$opts[:code]          = pit['code']
$opts[:logger]        = Logger.new($stdout, 'daily')
$opts[:logger].level  = Logger::DEBUG

begin
  load 'migrate.rb'
rescue Exception => e
  load File.expand_path('migrate.rb')
end

Net::IRC::Server.new($opts[:host], $opts[:port], FacebookIrcGateway::Server, $opts).start

