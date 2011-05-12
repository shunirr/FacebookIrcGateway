#!/usr/bin/env ruby
require 'rubygems'
require 'oauth'
require 'facebook_oauth'
require 'yaml'

config = YAML.load(open('config.yaml').read)
client = FacebookOAuth::Client.new(
    :application_id     => config['app']['id'],
    :application_secret => config['app']['secret'],
    :callback           => config['app']['callback']
)

# ここにアクセスして Success ってでたページの URL を良く見ろ!!
print client.authorize_url(:scope => 'offline_access, publish_stream, user_status, read_stream')


