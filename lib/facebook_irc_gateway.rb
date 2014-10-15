require 'net/irc'
require 'active_record'
require 'ya2yaml'
require 'facebook_oauth'
require 'facebook_irc_gateway/version'
require 'facebook_irc_gateway/ext'
require 'facebook_irc_gateway/utils' #TODO: オープンクラスが理由でautoloadできない

module FacebookIrcGateway
  module Model
    autoload :Channel, 'facebook_irc_gateway/models/channels'
  end
  autoload :Duplication, 'facebook_irc_gateway/models/duplication'
  autoload :UserFilter, 'facebook_irc_gateway/models/user_filter'

  autoload :Server,  'facebook_irc_gateway/server'
  autoload :Session,  'facebook_irc_gateway/session'
  autoload :Channel, 'facebook_irc_gateway/channel'
  autoload :NewsFeedChannel, 'facebook_irc_gateway/channel'
  autoload :TypableMap, 'facebook_irc_gateway/typable_map'
  autoload :CommandManager, 'facebook_irc_gateway/command_manager'
  autoload :Constants, 'facebook_irc_gateway/constants'

  autoload :User, 'facebook_irc_gateway/feed'
  autoload :Feed, 'facebook_irc_gateway/feed'
  autoload :Like, 'facebook_irc_gateway/feed'
  autoload :Comment, 'facebook_irc_gateway/feed'
  autoload :Feeds, 'facebook_irc_gateway/feed'
  autoload :Friends, 'facebook_irc_gateway/feed'
  autoload :UserFilters, 'facebook_irc_gateway/user_filters'
end

