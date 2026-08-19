# Tottoku

SNSやWebで見つけた投稿を、あとで見返すために保存・整理する個人用iPhoneアプリです。

Instagram、X、Threads、Safariなどから共有し、URL・テキストを受け取ってライブラリへ保存することを目指しています。OpenAI APIや独自サーバーは使用せず、将来的にはAppleのオンデバイスAIによる分類を追加します。

## 現在できること

- URL、タイトル、カテゴリ、タグ、要約、メモを手動で保存
- Pinterest風のライブラリ表示
- キーワード検索とカテゴリ絞り込み
- 保存内容の詳細表示・編集・元URLを開く
- カテゴリの追加と非表示化
- Share ExtensionからURL・テキストを受け取り、App Groupの受信箱へ安全に一時保存

> Share Extensionで受け取った内容を、ライブラリへ自動で取り込む処理は次のステップで追加します。

## 必要な環境

- macOS
- Xcode 26以降
- iOS 26以降（現在の開発ターゲット）
- 実機で共有機能を試す場合はApple DeveloperのSigning設定

## 起動方法

1. [Tottoku.xcodeproj](Tottoku.xcodeproj) をXcodeで開きます。
2. `Tottoku` スキームを選び、iPhoneシミュレータまたは実機を選びます。
3. 実機の場合は `Signing & Capabilities` で自分のTeamを選択します。
4. 実行します。

シミュレータでは、まず右上の「＋」からURLを手動保存してライブラリ、検索、編集を確認できます。

## Share Extensionの実機設定

Share Extensionは本体アプリと同じApp Groupを使って、受け取った内容を安全に受信箱へ保存します。

実機で試す前に、次の設定を確認してください。

1. `Tottoku` ターゲットの `Signing & Capabilities` で **App Groups** を追加します。
2. `ShareExtension` ターゲットにも **App Groups** を追加します。
3. 両方で `group.com.tottoku.app` を有効にします。
4. 実機にアプリをインストールし、Safariなどで共有シートを開きます。
5. 「Tottokuに保存」を選び、投稿を実行します。

実際にApp Storeへ配布する場合は、`com.tottoku.app` と `group.com.tottoku.app` を自分が所有する一意の識別子へ変更してください。次の3箇所は必ず同じApp Group IDに保ちます。

- `Tottoku/Tottoku.entitlements`
- `ShareExtension/ShareExtension.entitlements`
- `Tottoku/Sharing/SharedInbox.swift`

## 現在の構成

```text
共有元アプリ
  ↓
ShareExtension
  ↓ URL・テキストを即時保存
App Group / IncomingShares
  ↓ （次のステップで実装）
SwiftData
  ↓
ライブラリ / 検索 / 詳細
```

Share Extension内ではAI分類やネットワーク取得を行いません。拡張機能が終了しても保存が失われないよう、まず小さな受信データだけを保存する設計です。

## 開発状況

| Step | 内容 | 状態 |
| --- | --- | --- |
| 1 | SwiftDataのライブラリ、検索、編集、カテゴリ管理 | 完了 |
| 2 | Share ExtensionとApp Group受信箱 | 完了 |
| 3 | 受信箱からSwiftDataへの取り込み | 次回 |
| 4 | Apple Foundation Modelsによる分類とフォールバック | 未着手 |
| 5 | CloudKit同期、画像、仕上げ | 未着手 |

## ビルド確認

Xcodeからのビルドに加えて、次のコマンドでiOS Simulator向けに確認できます。

```sh
xcodebuild \
  -project Tottoku.xcodeproj \
  -scheme Tottoku \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/tottoku-derived \
  build CODE_SIGNING_ALLOWED=NO
```
