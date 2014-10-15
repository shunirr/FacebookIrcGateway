#!/usr/bin/env ruby
$:.unshift './lib', './'
require 'bundler'
Bundler.require
require 'facebook_irc_gateway/ext'
require 'facebook_irc_gateway/utils'
require 'active_support/core_ext/numeric/time'

def noecho
  `stty -echo`
  yield
  `stty echo`
end

DEFAULT_APP_ID = '221646024527845'
DEFAULT_APP_SECRET = '012749b22fcc3111ea88760c209cdb27'
CALLBACK_URL = 'https://www.facebook.com/connect/login_success.html'

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
if (id = gets.strip) != ''
  print I18n.t('setup.app_secret')
  if (secret = gets.strip) != ''
    app_id = id
    app_secret = secret
  end
end

client = FacebookOAuth::Client.new(:application_id => app_id,
                                   :application_secret => app_secret,
                                   :callback => CALLBACK_URL)

auth_url = client.authorize_url :response_type => 'token', :scope => PERMISSIONS.join(',')

begin
  agent = Mechanize.new
  agent.get auth_url do |login_page|
    login_page.form_with :id => 'login_form' do |form|
      print I18n.t('setup.email')
      form.email = gets.strip
      print I18n.t('setup.password')
      noecho { form.pass = gets.strip }
      puts ''

      success_page = form.submit
      if success_page.uri.path == URI(CALLBACK_URL).path
        params = Hash[*success_page.uri.fragment.split('&').map { |s| s.split('=') }.flatten]

        access_token = params['access_token']
        expires_in = params['expires_in'].to_i

        Pit.set('facebook_irc_gateway', :data => {
          'id' => app_id,
          'secret' => app_secret,
          'token' => access_token
        })

        puts I18n.t('setup.complete')
        puts I18n.t('setup.expires_in', :date => expires_in.seconds.since)
      else
        puts I18n.t('setup.access_to')
        puts FacebookIrcGateway::Utils.shorten_url auth_url
      end
    end
  end
rescue => e
  puts I18n.t('setup.fail')
  puts e
end
