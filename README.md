# Facebook Irc Gateway

## なにができるの？
Facebook を IRC 経由でアレしたりコレしたり出来ます。

- news feed (Friend timeline) の取得・表示
- news feed 上のコメントの取得・表示
- feed のアップデート

## つかうまえに
Facebook のアプリを申請しましょう。

- http://www.facebook.com/developers/

アプリ ID と秘訣を使って、 CODE を取得しましょう。

    ./oauth.rb

でてきた URL にブラウザでアクセスして、アプリを許可します。
Success と表示されたページの URI 末尾のなんかあれをこうします。

## ひつようなもの
- Ruby
- rubygems
- net/irc
- oauth
- facebook_oauth

## つかいかた
config.yaml を設定する

起動する

    ./fig.rb

IRC クライアントで繋ぐ。 (デフォルトだと 16822 あたりのポートを Listen する)

## 今後のやる気次第
- Like 対応
- TypableMap 的なもので Like したりコメントする

