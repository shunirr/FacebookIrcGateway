# Facebook Irc Gateway

Warning: This project does not currently work due to specification change of API on fb side.

Japanese below

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

- Ruby 1.9.2 or higher (Unsupport Ruby 1.8.x)
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

## More infomation

https://github.com/shunirr/FacebookIrcGateway/wiki

## Credits
- Project Leader:
  - shunirr
- Assistants
  - ssig33
  - mashiro
  - ラーメン二郎
- Special thx
  - yutamoty

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

- Ruby 1.9.2 以上 (1.8.x はサポートしません)
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

## 更に詳しく知りたい

https://github.com/shunirr/FacebookIrcGateway/wiki/Home_ja


# License

The MIT License (MIT)

Copyright (c) Shinshun Kuniyoshi 2014

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

