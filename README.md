# Peercast Gateway

## 概要

ピアキャストに配信するサービス Peercast Gateway
(http://pcgw.sun.ddns.vc/) の Web インターフェイスです。
Sinatra で書かれています。

サービス全体は次のものに依存しています。

* PeerCast Station (http://www.pecastation.org/)
* mirror (https://github.com/plonk/mirror)
* stream_proxy (https://github.com/plonk/stream_proxy)
* Graphviz

## インストール (書きかけ)

* twitter アプリケーションのキーを取得する
* 適切な設定ファイル config/config.yml を書く
* PeerCast Station と mirror と stream_proxy とが起動している状態にする
* 管理ユーザーを作る
