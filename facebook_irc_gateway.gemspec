# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "facebook_irc_gateway/version"

Gem::Specification.new do |s|
  s.name        = "facebook_irc_gateway"
  s.version     = FacebookIrcGateway::VERSION
  s.authors     = ["AKAMATSU Yuki"]
  s.email       = ["y.akamatsu@ukstudio.jp"]
  s.homepage    = ""
  s.summary     = %q{IRC Gateway for Facebook}
  s.description = %q{IRC Gateway for Facebook}

  s.rubyforge_project = "facebook_irc_gateway"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency 'oauth', '=0.4.4'
  s.add_dependency 'oauth2', '=0.4.1'
  s.add_dependency 'facebook_oauth'
  s.add_dependency 'net-irc', '=0.0.9'
  s.add_dependency 'pit', '=0.0.6'
  s.add_dependency 'ya2yaml', '=0.30'
  s.add_dependency 'sqlite3', '=1.3.3'
  s.add_dependency 'activerecord', '=3.0.7'
  s.add_dependency 'activesupport', '=3.0.7'
  s.add_dependency 'i18n', '=0.5.0'
  s.add_dependency 'rake', '=0.8.7'
  s.add_development_dependency 'rspec','=2.6.0'
  s.add_development_dependency 'webmock', '=1.6.4'
end
