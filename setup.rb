#!/usr/bin/env ruby
$:.unshift './lib', './'
require 'bundler'
Bundler.require
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

PERMISSIONS = %w(
  user_about_me
  user_actions.books
  user_actions.fitness
  user_actions.music
  user_actions.news
  user_actions.video
  user_birthday
  user_education_history
  user_events
  user_friends
  user_games_activity
  user_groups
  user_hometown
  user_likes
  user_location
  user_managed_groups
  user_photos
  user_posts
  user_relationship_details
  user_relationships
  user_religion_politics
  user_status
  user_tagged_places
  user_videos
  user_website
  user_work_history
  read_stream
)

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

oauth = Koala::Facebook::OAuth.new app_id, app_secret, CALLBACK_URL
auth_url = oauth.url_for_oauth_code :permissions => PERMISSIONS

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
        code = Hash[*success_page.uri.query.split('&').map { |s| s.split('=') }.flatten]['code']
        params = oauth.get_access_token_info code

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
