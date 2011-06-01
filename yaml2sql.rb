#!/usr/bin/env ruby

$LOAD_PATH << (RUBY_VERSION > '1.9' ? './lib' : 'lib')
$KCODE = 'u' unless defined? ::Encoding

require 'rubygems'
require 'bundler'
#Bundler.require
require 'optparse'
require 'yaml'

require 'facebook_irc_gateway'

config_path = 'config.yaml'
my_user_id = nil #'1627174318' #your id

if my_user_id.nil?
  p "no id set"
  exit
end

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

opts = {}
begin
  YAML::load_file(config_path).each do |k, v|
    if k == 'color'
      opts[k.to_sym] = {}
      v.each do |kk,vv|
        opts[k.to_sym][kk.to_sym] = vv.to_sym
      end
    else
      opts[k.to_sym] = v
    end
  end
rescue Exception => e
#  puts 'Fail to load config file...'
#  exit -1
end

opts[:userlist]      = 'userlist.yaml' if opts[:userlist].nil?
opts[:db] = YAML.load_file('database.yml')

system('rake db:migrate')

ActiveRecord::Base.establish_connection(
  :adapter  => opts[:db]['adapter'],
  :database => opts[:db]['database']
)

rel = FacebookIrcGateway::UserFilter.where( :user_id => my_user_id )
userlist = YAML::load_file(opts[:userlist])
userlist.each do |id,user|
  if user['alias_enable'] or user['enable']
    rec = rel.find_or_initialize_by_object_id( id )
    rec.alias = user['name']
    rec.save
  end
end
