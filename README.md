# Tottoku

SNSやWebで見つけた投稿を、あとで見返すために保存・整理する個人用iPhoneアプリです。

Instagram、X、Threads、Safariなどから共有し、URL・テキストを受け取ってライブラリへ保存する個人用アプリです。OpenAI APIや独自サーバーは使用しません。

## 現在できること

- URL、タイトル、カテゴリ、タグ、要約、メモを手動で保存
- Pinterest風のライブラリ表示
- キーワード検索とカテゴリ絞り込み
- 保存内容の詳細表示・編集・削除・元URLを開く
- カテゴリの追加、名前変更、並び替え、非表示化
- Share ExtensionからURL・テキストを受け取り、App Groupの受信箱へ安全に一時保存
- 共有をアプリ起動時にライブラリへ自動取り込み
- リンク先の公開メタデータから、タイトルとサムネイルを補完（取得できる場合のみ）
- Apple Foundation Modelsが利用可能な端末ではオンデバイスでカテゴリ・タグ・要約を自動分類。利用不可時はルールベースで分類

XやInstagramなどは共有時にURLだけを渡す場合があります。その場合、投稿本文そのものは保存できませんが、公開リンクのタイトル・画像を補完できる場合があります。詳細画面の「リンク情報を再取得」から再試行もできます。

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
  ↓ アプリ起動時・復帰時に自動取り込み
SwiftData
  ↓
リンク情報の補完・オンデバイス分類
  ↓
ライブラリ / 検索 / 詳細 / 編集
```

Share Extension内ではAI分類やネットワーク取得を行いません。拡張機能が終了しても保存が失われないよう、まず小さな受信データだけを保存する設計です。

## 開発状況

| Step | 内容 | 状態 |
| --- | --- | --- |
| 1 | SwiftDataのライブラリ、検索、編集、カテゴリ管理 | 完了 |
| 2 | Share ExtensionとApp Group受信箱 | 完了 |
| 3 | 受信箱からSwiftDataへの取り込み | 完了 |
| 4 | Apple Foundation Modelsによる分類とフォールバック | 完了 |
| 5 | 公開リンク情報のタイトル・サムネイル補完、管理操作 | 完了 |
| 6 | CloudKit同期 | Apple DeveloperでiCloudコンテナを準備後に実施 |

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
