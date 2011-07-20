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
end
