# 残作業

## 2026-07-03 リファクタリング第1弾(refactor/plan-v1)で対応済み

- 特性テスト・レポートパーサテスト・アクション実行テストを追加し、unit テストを 7 件から 36 件に拡充した。
- [B1] Bluetooth 再接続(stop → start)後に入力レポート購読が復活せず入力が届かなくなるバグを修正した(`JoyconHIDClient.stop()` / `handleRemoved` の状態クリア漏れ)。実機での再接続確認は未実施。
- [B2] マッパー無効化・Joy-Con 切断・停止の際に、押下中の修飾キーホールド / push-to-talk が解放されず macOS 上で押しっぱなしに固着するバグを修正した。
- [B3] Joy-Con (R) / Pro Controller が左用レポートパーサに流れて誤入力を生成していたため、HID マッチ対象を Joy-Con (L) のみに限定した(R 対応時にパーサとセットで復活させること)。
- [B4] UI テストの言語指定を launchEnvironment(無効)から launch arguments に修正した。日本語環境のローカル実行でも英語 UI でテストが通る。
- [B5] 入力ログ画面が実行時の表示名をローカライズキーとして解決していた偶然依存を解消した。
- [R2] 入力送出を `InputSending` プロトコル経由に変更し、アクション実行経路をテスト可能にした(挙動変更なし)。

## 2026-07-03 機能改善第1弾(feature/ux-improvements)で対応済み

- [F1] ポインタ移動を CGEvent(mouseMoved/mouseDragged)投稿に変更し、ドラッグ&ドロップとホバーが機能するようにした。「左ボタンを保持(ドラッグ)」アクションを追加(mouseHold)。座標は全ディスプレイ範囲にクランプ。
- [F2] アクセシビリティ許可の変更を2秒間隔で自動検知し、UI・メニューバーに即時反映するようにした。
- [F3] メニューバーに「設定ウィンドウを開く」とプロファイル切替を追加(WindowGroup → Window 化で単一ウィンドウに)。
- [F4] ショートカット録画時に keyCode を保存し、JIS 配列でも記号キーが正しく送出されるようにした(旧形式 JSON は keyCode なしで後方互換)。
- [CI] UI smoke test を「起動+メインウィンドウ描画」の検証に確定。調査の結果、CI ランナー(ヘッドレス macOS 26 VM)では (1) AppleLanguages 起動引数がウィンドウ提示自体を阻害する、(2) 合成クリックがアプリに届かない(ウィンドウが Disabled のまま)、(3) SwiftUI の sheet 提示が抑止される、という3つの環境制約があり、シート操作の自動検証は不可能。テストはロケール非依存の参照に統一済み(日本語環境のローカル実行も可)。
- 実機確認が必要: ドラッグ&ドロップ(Finder でのファイル移動)、ホバーでのツールチップ表示、JIS キーボードでの記号ショートカット、入力ログシートの開閉とクリア。

## 1.0.0 までに必要なこと

- CI 上で unit test、snapshot test、UI smoke test、Release build が安定して通ることを確認する。
- 実機 Joy-Con (L) でスティック移動、クリック、右クリック、D-pad スクロール、ショートカット割り当てを再確認する。
- 実機で「再接続」ボタンと Bluetooth 切断→再接続後に入力が復活することを確認する(B1 修正の実機検証)。
- 設定の import/export を実機操作で確認し、失敗時のエラー文言がユーザーに伝わるか確認する。
- Homebrew 経由の新規 install / upgrade を確認する。
- スリープ復帰、Joy-Con 未接続起動の挙動を確認する。
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
- `gh auth status` が invalid token になっているため、GitHub Release 作成前に `gh auth login -h github.com` で再認証するか、GitHub Web UI から release を作成する。
