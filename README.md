# Facebook Irc Gateway

## What's That
Facebook Client that spoof IRC server.

You can be as follows:

- Reading news feed.
- Reading comments on news feed.
- Update your status.
- Like using TypableMap.
- Comment using TypableMap.

## Before Using
First of All, need to setup environments.

This Application require

- Ruby 1.8.7 or higher(Testing on 1.9.2 and 1.8.7)
- Bundler gem

    gem install bundler

and need to setup Bundler

    bundle install

Second, run setup script.

    bundle exec ruby setup.rb

This Script generate config.

## Using
Run

    bundle exec ruby fig.rb

Have A FUN!!

## Typable Map Command

    19:40 (shunirr) Im so sleepy. (hoge) (via web)

You want to update comment this status:

    re hoge lets sleep together.

You want to like this status:

    like hoge

or 

    fav hoge

You want to delete just before update status:

    undo

## Todo
- Support Unlike.
- Support Group.
- Support Event.
- Support Question.
- Support user follow using TypableMap.
- Support shoten user name.
- Support channel.

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
- TypableMap を使って "いいね！"
- TypableMap を使ってコメント

## セットアップ
以下のソフトウェアに依存しています

- Ruby 1.8.7 以上(それ以下でも動くかもしれません、 1.9.2 と 1.8.7 で開発しています)
- Bundler gem

    gem install bundler

Bundler でセットアップします

    bundle install

最後にセットアップスクリプトを実行します

    bundle exec ruby setup.rb

以上で設定が生成され書き込まれます。なお API Secret は日本語表示では API の秘訣と表示されます。

## 実行
ここまでくれば実行するだけです

    bundle exec ruby fig.rb

Have A FUN!!

## Typable Map コマンド集

    19:40 (shunirr) ねむい (hoge) (via web)

この発言にコメントを付けたい場合:

    re hoge 一緒にねよう！

この発言をいいね！したい場合:

    like hoge

または

    fav hoge

直前の発言を消したい場合:

    undo


