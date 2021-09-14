# Peercast Gateway

## 概要

ピアキャストに配信するサービス Peercast Gateway
(http://pcgw.pgw.jp/) の Web インターフェイスです。
Sinatra で書かれています。

サービス全体は次のものに依存しています。

* [PeerCast YT](https://github.com/plonk/peercast-yt/)
* [mirror](https://github.com/plonk/mirror)
* [MatroskaServer](https://github.com/plonk/MatroskaServer)
* [cyarr](https://github.com/plonk/cyarr)
* Graphviz
* FFMPEG
* ImageMagick
* Nginx (with rtmp-module)

## とりあえず起動してみたい人向け

    $ bundle install --path vendor/bundle
    $ rake setup
    $ PCGW_ENV=production rake run
