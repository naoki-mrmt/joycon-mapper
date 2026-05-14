# Joycon Mapper

Joycon Mapper は、Nintendo Switch の Joy-Con (L) を macOS の小さなポインタ・ショートカットコントローラーとして使うためのメニューバーアプリです。

左スティックでマウスポインタを動かし、Joy-Con の各ボタンにはキーボードショートカット、修飾キーのホールド、マウスクリックなどを割り当てられます。

## Install

Homebrew でインストールできます。

```sh
brew tap naoki-mrmt/tap
brew install --cask joycon-mapper
```

インストール後、`/Applications/JoyconMapper.app` を起動してください。

初回起動時に macOS のアクセシビリティ許可が必要です。許可後、Joy-Con (L) を Bluetooth 接続すると入力が表示されます。

## Requirements

- macOS 26 以降
- Nintendo Switch Joy-Con (L)
- Bluetooth 接続
- アクセシビリティ許可

## Features

- 左スティックでマウスポインタを移動
- ポインタ速度、デッドゾーン、加速度、上下反転を調整
- プロファイルごとに Joy-Con ボタンと D-pad を割り当て
- 左スティック押し込みにもクリックやショートカットを割り当て
- プロファイルの作成、複製、名前変更、削除
- キーボードショートカットを録画して割り当て
- Command、Option、Shift、Option + Command などの修飾キーをホールド
- 左クリック、右クリック、矢印キー、戻る/進むなどのテンプレート割り当て
- D-pad やボタンへの縦横スクロール割り当て
- 未接続時の自動再検出
- 初回セットアップ案内
- 入力ログ表示
- 日本語・英語 UI
- アプリ内 About でバージョン、GitHub、MIT License を表示
- ログイン時に起動

## Setup

1. Joy-Con (L) を macOS に Bluetooth 接続します。
2. Joycon Mapper を起動します。
3. macOS のアクセシビリティ許可を付与します。
4. 左スティックを動かして、ポインタが動くことを確認します。
5. トップ画面のキー一覧から、各ボタンに好きな動作を割り当てます。

## Notes

Joy-Con には macOS の音声入力として使えるマイクはありません。このアプリはミュートや push-to-talk などのショートカットを操作できますが、Joy-Con 自体をマイクとして使うことはできません。

Joy-Con 接続時に macOS の集中モード「ゲーム」が有効になる場合は、`システム設定 > 集中モード > ゲーム` で、ワイヤレスコントローラーによる自動起動を無効にしてください。このアプリ自体は Utilities アプリとして宣言していますが、コントローラー接続が macOS 側の自動化を起動する場合があります。

## Uninstall

```sh
brew uninstall --cask joycon-mapper
```

設定も消したい場合:

```sh
rm ~/Library/Preferences/com.muramoto-co.JoyconMapper.plist
```

## Development

Open `JoyconMapper.xcodeproj` in Xcode and run the `JoyconMapper` scheme.

Command-line build:

```sh
xcodebuild \
  -project JoyconMapper.xcodeproj \
  -scheme JoyconMapper \
  -configuration Debug \
  -derivedDataPath .build/xcode \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Release

Public releases are signed with a Developer ID Application certificate, notarized by Apple, attached to GitHub Releases, and distributed through Homebrew Cask.

Release docs:

- [DISTRIBUTION.md](DISTRIBUTION.md)
- [RELEASE.md](RELEASE.md)

## License

MIT License. See [LICENSE](LICENSE).
