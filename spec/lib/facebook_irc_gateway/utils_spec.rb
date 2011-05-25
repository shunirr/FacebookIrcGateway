# coding: utf-8
require 'spec_helper'

describe FacebookIrcGateway::Utils do
  describe 'shorten_url' do
    subject { FacebookIrcGateway::Utils.shorten_url(url) }

    context 'URLが19文字以下' do
      let(:url) { 'http://twitter.com' }
      it { should  eq 'http://twitter.com' }
    end

    context 'URLが20文字以上' do
      let(:url) { 'http://twitter.com/#!/shunirr/favorites' }
      before do
        FacebookIrcGateway::Utils.stub(:request_short_url) do
  "{\n \"kind\": \"urlshortener#url\",\n \"id\": \"http://goo.gl/nUZiB\",\n \"longUrl\": \"http://twitter.com/#!/shunirr/favorites\"\n}\n"
        end
      end

      it { should eq 'http://goo.gl/nUZiB' }
    end

    context '短縮URLが14文字以下' do
      let(:url) { 'http://twitter.com/#!/shunirr/favorites' }
      before do
        FacebookIrcGateway::Utils.stub(:request_short_url) do
  "{\n \"kind\": \"urlshortener#url\",\n \"id\": \"http://goo.gl/\",\n \"longUrl\": \"http://twitter.com/#!/shunirr/favorites\"\n}\n"
        end
      end

      it { should eq 'http://twitter.com/#!/shunirr/favorites' }
    end
  end

  describe 'url_filter' do
    let(:message) { "playing: ほげほげ http://twitter.com/shunirr" }
    before do
      FacebookIrcGateway::Utils.stub(:shorten_url) do
        "http://goo.gl/shorted"
      end
    end
    subject { FacebookIrcGateway::Utils.url_filter(message) }
    it { should eq 'playing: ほげほげ http://goo.gl/shorted' }
  end
end
