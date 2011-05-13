#!/usr/bin/env ruby
require 'rubygems'
require 'oauth'
require 'facebook_oauth'

#config = YAML.load(open('config.yaml').read)
config = {'app' => {}}

print "Input your Application ID: "
config['app']['id'] = gets.chomp
print "Input your Application Secret: "
config['app']['secret'] = gets.chomp
config['app']['callback'] = 'http://www.facebook.com/connect/login_success.html'
client = FacebookOAuth::Client.new(
    :application_id     => config['app']['id'],
    :application_secret => config['app']['secret'],
    :callback           => config['app']['callback']
)


puts "---"
puts client.authorize_url(:scope => 'offline_access, publish_stream, user_status, read_stream')
puts "---"
print "Please access this URL, and Paste param 'code': "
code = gets.chomp

puts "Paste this to your Pit"
puts <<EOS
---
id: #{config['app']['id']}
secret: #{config['app']['secret']}
callback: #{config['app']['callback']}
code: #{code}
EOS
