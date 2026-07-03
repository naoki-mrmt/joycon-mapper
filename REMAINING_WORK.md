# 残作業

## 1.0.0 までに必要なこと

- CI 上で unit test、snapshot test、UI smoke test、Release build が安定して通ることを確認する。
- 実機 Joy-Con (L) でスティック移動、クリック、右クリック、D-pad スクロール、ショートカット割り当てを再確認する。
- 設定の import/export を実機操作で確認し、失敗時のエラー文言がユーザーに伝わるか確認する。
- Homebrew 経由の新規 install / upgrade を確認する。
- スリープ復帰、Bluetooth 再接続、Joy-Con 未接続起動の挙動を確認する。
- README、RELEASE、DISTRIBUTION の内容を 1.0.0 時点の仕様に合わせて最終更新する。

## 1.0.0 以降で検討すること

- SwiftUI 画面の画像 snapshot test を、CI でハングしない方法に絞って再検討する。
- Joy-Con (R) 対応。
- 複数 Joy-Con 接続時のプロファイル切り替え。
- より細かいマウス加速度・デッドゾーン調整。
- アプリ内ヘルプまたは初回セットアップガイドの改善。

## 今回の 0.9.1 リリースで確認したいこと

- Point-Free SnapshotTesting のテキスト snapshot が CI で通る。
- 入力ログのクリア処理が unit test で保証される。
- import 失敗時のエラー分類が unit test で保証される。
- UI smoke test が CI 上で起動と入力ログ表示まで確認できる。

## 0.9.1 リリースブロッカー

- Apple notarytool が `A required agreement is missing or has expired` で失敗しているため、Apple Developer / App Store Connect 側で必要な契約に同意する。
- 契約同意後に `CODESIGN_IDENTITY="Developer ID Application: Naoki Muramoto (JFWN5K94GG)" NOTARY_PROFILE="joycon-mapper-notary" ./scripts/package-release.sh 0.9.1` を再実行する。
- notarize 済み zip を `./scripts/verify-release.sh 0.9.1` で検証してから GitHub Release と Homebrew tap 更新へ進む。
