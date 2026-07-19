# 残作業

## 2026-07-19 バグ潰し+安定化(feature/v0.11.0-stability)で対応済み

6観点の網羅的コード監査(並行性/入力ステートマシン/HID/新規F1-F4/永続化/UI)を並列実施し、確定した実害バグを修正した。

- [SM1] プロファイル切替・割り当て変更を hold 中に行うと、解放処理が変更後の可変プロファイルを参照するためキー/修飾/マウスが物理的に張り付く不具合を修正(発火した実アクションを保存し、そこから解放)。
- [H1] Joy-Con (L) を2台接続すると id 重複で `Dictionary(uniqueKeysWithValues:)` が fatalError → クラッシュする不具合を修正(uniquingKeysWith)。あわせてデバイス列挙の nil を「取得失敗」として扱い一覧が一瞬空になるのを防止。
- [FH1] アプリ終了(Quit / Cmd-Q)時に保持中の mouseHold / modifierHold / pushToTalk が解放されず、システム全体でキー/マウスが張り付く不具合を修正(willTerminate で stop)。
- [P1/P2] 保存済み設定(profiles / profileOptions)が破損して decode 失敗した際に、既定値で無言リセット+即上書きしてユーザーのマッピングが全損する不具合を修正(破損時は上書きしない)。
- [P3] import 経由で組み込みでないプロファイルが先頭にある状態で削除すると activeProfileID が削除対象自身を指し UI 操作不能になる境界バグを修正。
- [P4/P5] import 時の profileOption id 重複排除、v1→v2 移行後の legacy キー削除。
- [C3] stop 直後に enqueue 済みタイマー Task が発火してカーソルが動くのを防止(guard isRunning)。
- [U1] 入力ログを開いたまま Record Shortcut を選ぶとレコーダーが提示されない(2枚シート競合)を修正。
- [U2] ファイル保存/読み込みのキャンセルで誤エラーアラートが出るのを抑止。
- [U3] ショートカット録画中に他アプリへ切替(Cmd+Tab 等)するとバックグラウンドで割当が確定する不具合を修正。
- [U4/U5/FL2/FL3] 入力ログ選択のダングリング、スティックプレビューの座標クランプ、hold 中ボタンの click 抑止、メニューバーからのウィンドウ再表示の堅牢化。
- 新機能: スリープ復帰時の自動再接続、緊急無効化グローバルホットキー(⌃⌥⌘Esc)。
- unit テストを 48 件から 60 件超へ拡充。

### 実機検証してから対応する保留項目(現行アプリは実機で動作しているため盲目変更を避けた)
- 0x3F レポートのレイアウト解釈、reportID プレフィックス補完、value/report の二重入力経路、D-pad の control.id 統一(H2/H5/H6/SM2)。実機でどのレポートが届くかログを取ってから。
- onInput/onDevicesChanged の Task 順序(C1/C5)。`MainActor.assumeIsolated` 化が候補だが入力ホットパスのため実機確認とセットで。
- stop / handleRemoved の per-device HID コールバック解除(C2/H4)。IOHIDManagerClose が配送を止める前提だと投機的で、構造変更を伴うため実機で検証。
- handleRemoved のデバイス安定キー化(H3)。

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
