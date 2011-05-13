# Facebook Irc Gateway

## What's That
Facebook Client that spoof IRC server.

You can be as follows:

- Reading news feed.
- Reading comments on news feed.
- Update your status.

## Before Using
First of All, need to setup environments.

This Application require

- Ruby 1.8.7 or higher(Testing on 1.9.2 and 1.8.7)
- Bundler gem

    gem install bundler

and need to setup Bundler

    bundle install

Second, run setup script.

    bundle exec ruby oauth.rb

This Script generate config for Pit.

## Using
Run

    bundle exec ruby fig.rb

and when editor appers, paste config that generated before.

Have A FUN!!

## Todo
- Support Like
- Support TypableMap

## Credits
- Project Leader:
  - shunirr
- Assistants
  - ssig33
  - ラーメン二郎


## Japanese
## これは何？
IRC サーバーのふりをする Facebook クライアントです

以下のことが出来ます

- ニュースフィードの閲覧
- ニュースフィードについたコメントの閲覧
- ステータスの更新


## セットアップ
以下のソフトウェアに依存しています

- Ruby 1.8.7 以上(それ以下でも動くかもしれません、 1.9.2 と 1.8.7 で開発しています)
- Bundler gem

    gem install bundler

Bundler でセットアップします

    bundle install

最後にセットアップスクリプトを実行します

    bundle exec ruby oauth.rb

Pit に貼り付ける為の設定ファイルが生成されます。なお API Secret は日本語表示では API の秘訣と表示されます。

## 実行
ここまでくれば実行するだけです

    bundle exec ruby fig.rb

エディタが表示されるので、先程生成した設定を貼り付けましょう。

Have A FUN!!

