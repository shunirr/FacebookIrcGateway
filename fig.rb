#!/usr/bin/env ruby
$:.unshift './lib', './'
$KCODE = 'u' unless defined? ::Encoding

require 'rubygems'
require 'bundler'
Bundler.require
require 'optparse'
require 'yaml'
require 'logger'
require 'active_support/core_ext'
require 'facebook_irc_gateway'

pit = Pit.get('facebook_irc_gateway', :require => {
  'id' => 'Application ID',
  'secret' => 'Application Secret',
  'token' => 'Your Access Token'
})

options = {
  :config_path => 'config.yaml',
  :host => '127.0.0.1',
  :port => 16822,
  :userlist => 'userlist.yaml',
  :autoliker => false,
  :locale => :en,
  :color => {
    :tid => :teal,
    :app_name => :teal,
    :like => :teal,
    :parent_message => :gray,
  },
  :suffix => '',
  :app_id => pit['id'],
  :app_secret => pit['secret'],
  :access_token => pit['token'],
}.with_indifferent_access

OptionParser.new do |opts|
  opts.on('-c', "--config [CONFIG=#{options[:config_path]}]", 'path to config.yaml') do |path|
    options[:config_path] = path
  end

  opts.on('-h', '--help', 'show help') do
    puts opts
    exit
  end

  opts.on('-v', '--version', 'show version') do
    puts FacebookIrcGateway::VERSION
    exit
  end

  opts.parse!(ARGV)
end

# load from file
override_options = YAML::load_file(options[:config_path]) rescue {}
options.deep_merge! override_options

def symbolize_values(options, *keys)
  keys = keys.map { |k| k.to_s }
  options.each do |k, v|
    if keys.empty? || keys.include?(k.to_s)
      case v
      when ::Hash
        symbolize_values(v)
      when ::String
        options[k] = v.to_sym
      end
    end
  end
end

# sanitize
symbolize_values options, :locale, :color

options[:db] = YAML.load_file('database.yml')
options[:logger] = Logger.new($stdout, 'daily').tap do |logger|
  logger.level = Logger::DEBUG
end

system('rake db:migrate')

Thread.start do
  server = Net::IRC::Server.new(options[:host], options[:port], FacebookIrcGateway::Server, options)
  server.start
end

EventMachine.threadpool_size = 3
EventMachine.run

