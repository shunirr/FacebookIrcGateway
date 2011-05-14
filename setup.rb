#!/usr/bin/env ruby
require 'rubygems'
require 'oauth'
require 'facebook_oauth'
require 'pit'

DEFAULT_APP_ID = '221646024527845'
DEFAULT_APP_SECRET = '012749b22fcc3111ea88760c209cdb27'

config = {'app' => {}}

print "Input your Application ID: (Press enter, if use default Application ID): "
app_id = gets.chomp
if app_id == ''
  config['app']['id']     = DEFAULT_APP_ID
  config['app']['secret'] = DEFAULT_APP_SECRET
else
  config['app']['id'] = app_id
end

unless config['app']['secret']
  print "Input your Application Secret: "
  config['app']['secret'] = gets.chomp
end

config['app']['callback'] = 'http://www.facebook.com/connect/login_success.html'
client = FacebookOAuth::Client.new(
    :application_id     => config['app']['id'],
    :application_secret => config['app']['secret'],
    :callback           => config['app']['callback']
)


puts "---"
puts client.authorize_url(:scope => 'offline_access, publish_stream, user_status, read_stream')
puts "---"
print "Please access this URL, and Allow this Application, and Paste new URL: "
code = gets.chomp.split("code=").last

Pit.set("facebook_irc_gateway", :data => {
  'id' => config['app']['id'],
  'secret' => config['app']['secret'],
  'callback' => config['app']['callback'],
  'code' => code
})

puts "Complete Setup!!"
