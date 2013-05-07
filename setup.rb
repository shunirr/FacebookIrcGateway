#!/usr/bin/env ruby
$:.unshift './lib', './'
require 'bundler'
Bundler.require
require 'facebook_irc_gateway/utils'

class FacebookOAuth::Client
  # XXX: Fuck'in method
  def authorize_url(options = {})
    default_options = {
      :client_id => @application_id,
      :redirect_uri => @callback,
      :scope => 'offline_access,publish_stream',
    }
    client.auth_code.authorize_url default_options.merge(options)
  end
end

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

begin
  config_yaml = YAML::load_file('config.yaml')
rescue Exception => e
  config_yaml = {'locale' => 'en'}
end
I18n.load_path += Dir['lib/facebook_irc_gateway/locale/*.yml']
I18n.default_locale = config_yaml['locale'].to_sym

app_id = DEFAULT_APP_ID
app_secret = DEFAULT_APP_SECRET

print I18n.t('setup.app_id')
if (id = gets.chomp) != ''
  print I18n.t('setup.app_secret')
  if (secret = gets.chomp) != ''
    app_id = id
    app_secret = secret
  end
end

client = FacebookOAuth::Client.new(:application_id => app_id,
                                   :application_secret => app_secret,
                                   :callback => 'https://www.facebook.com/connect/login_success.html')

auth_url = client.authorize_url :response_type => 'token', :scope => PERMISSIONS.join(',')

puts '--------------------'
puts "#{FacebookIrcGateway::Utils.shorten_url auth_url}"
puts '--------------------'

print I18n.t('setup.access_to')
access_token = /access_token=(\w+)/.match(gets)[1]

Pit.set('facebook_irc_gateway', :data => {
  'id' => app_id,
  'secret' => app_secret,
  'token' => access_token
})

puts I18n.t('setup.complete')

