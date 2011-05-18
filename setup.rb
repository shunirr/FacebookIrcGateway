#!/usr/bin/env ruby

$LOAD_PATH << 'lib'
require 'rubygems'
require 'oauth'
require 'facebook_oauth'
require 'pit'

require 'facebook_irc_gateway/utils'

DEFAULT_APP_ID = '221646024527845'
DEFAULT_APP_SECRET = '012749b22fcc3111ea88760c209cdb27'

PERMISSIONS = [
  'user_about_me', 'friends_about_me', 'user_activities', 'friends_activities', 
  'user_birthday', 'friends_birthday', 'user_checkins', 'friends_checkins', 
  'user_education_history', 'friends_education_history', 'user_events', 'friends_events', 
  'user_groups', 'friends_groups', 'user_hometown', 'friends_hometown', 
  'user_interests', 'friends_interests', 'user_likes', 'friends_likes', 
  'user_location', 'friends_location', 'user_notes', 'friends_notes', 
  'user_online_presence', 'friends_online_presence', 'user_photo_video_tags', 'friends_photo_video_tags', 
  'user_photos', 'friends_photos', 'user_relationships', 'friends_relationships', 
  'user_relationship_details', 'friends_relationship_details', 'user_religion_politics', 'friends_religion_politics', 
  'user_status', 'friends_status', 'user_videos', 'friends_videos', 
  'user_website', 'friends_website', 'user_work_history', 'friends_work_history', 
  'email', 'read_friendlists', 'read_insights', 'read_mailbox', 
  'read_requests', 'read_stream', 'xmpp_login', 'ads_management', 
  'publish_stream', 'create_event', 'rsvp_event', 'offline_access',
  'publish_checkins', 'manage_friendlists', 'manage_pages'
]

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

config['app']['callback'] = 'https://www.facebook.com/connect/login_success.html'
client = FacebookOAuth::Client.new(
    :application_id     => config['app']['id'],
    :application_secret => config['app']['secret'],
    :callback           => config['app']['callback']
)

auth_url = client.authorize_url :scope => PERMISSIONS.join(',')
puts "---"
puts "#{FacebookIrcGateway::Utils.shorten_url auth_url}"
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
