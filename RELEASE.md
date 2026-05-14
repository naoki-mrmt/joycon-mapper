# リリース手順

Joycon Mapper は、署名・notarize 済みの GitHub Release アーティファクトを作り、その URL を Homebrew Cask から参照して配布します。

## 初回だけやること

### 1. Apple Developer Program に参加する

公開配布向けの notarize には Apple Developer Program が必要です。手元の開発用 `Apple Development` 証明書だけでは、一般ユーザー向けの配布には足りません。

### 2. Developer ID Application 証明書を入れる

Apple Developer で作成してダウンロードするか、Xcode の Accounts から管理します。

Keychain に入っているか確認します。

```sh
security find-identity -v -p codesigning
```

次のような行が出れば OK です。

```text
Developer ID Application: Your Name (TEAMID)
```

### 3. Notary Profile を作る

Apple の notarize 用認証情報を Keychain に保存します。

```sh
xcrun notarytool store-credentials joycon-mapper-notary
```

聞かれたら Apple ID、Team ID、アプリ用パスワードを入力します。

### 4. 配布前提をチェックする

```sh
./scripts/check-distribution-prereqs.sh
```

ここで次の 2 つが通れば、署名・notarize 付きリリースを作れます。

- `Developer ID Application` 証明書がある
- `joycon-mapper-notary` の notarytool profile が使える

### 5. Homebrew Tap を用意する

例として次のリポジトリを作ります。

```text
naoki-mrmt/homebrew-tap
```

Cask ファイルは tap 側のここに置きます。

```text
Casks/joycon-mapper.rb
```

## 毎回のリリース手順

以下は `0.8.0` をリリースする例です。実際のバージョンに置き換えてください。

### 1. 作業ツリーを確認する

```sh
git status --short
```

リリースに含める変更はコミットしておきます。関係ない作業が混ざっている場合は、先に片付けるか意図的に残します。

### 2. Release ビルドを確認する

```sh
xcodebuild \
  -project JoyconMapper.xcodeproj \
  -scheme JoyconMapper \
  -configuration Release \
  -derivedDataPath .build/xcode-release-check \
  CODE_SIGNING_ALLOWED=NO \
  clean build
```

### 3. 署名・notarize 済み zip を作る

```sh
CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="joycon-mapper-notary" \
./scripts/package-release.sh 0.8.0
```

生成物は次の 2 つです。

```text
.build/dist/JoyconMapper-v0.8.0.zip
.build/dist/JoyconMapper-v0.8.0.zip.sha256
```

### 4. Gatekeeper の確認をする

一時ディレクトリに展開します。

```sh
rm -rf /tmp/JoyconMapperReleaseCheck
mkdir -p /tmp/JoyconMapperReleaseCheck
ditto -x -k .build/dist/JoyconMapper-v0.8.0.zip /tmp/JoyconMapperReleaseCheck
```

アプリを検証します。

```sh
spctl -a -vvv -t exec /tmp/JoyconMapperReleaseCheck/JoyconMapper.app
codesign --verify --deep --strict --verbose=2 /tmp/JoyconMapperReleaseCheck/JoyconMapper.app
```

`spctl` が `accepted` を返せば OK です。

### 5. Git tag を作る

```sh
git tag v0.8.0
git push origin v0.8.0
```

### 6. GitHub Release を作る

GitHub CLI の認証が使える場合:

```sh
gh release create v0.8.0 \
  .build/dist/JoyconMapper-v0.8.0.zip \
  .build/dist/JoyconMapper-v0.8.0.zip.sha256 \
  --title "Joycon Mapper v0.8.0" \
  --notes "Signed and notarized macOS build."
```

GitHub CLI の認証が壊れている場合は、GitHub の Web UI で release を作り、同じ 2 ファイルをアップロードします。

Release URL はこの形になります。

```text
https://github.com/naoki-mrmt/joycon-mapper/releases/tag/v0.8.0
```

### 7. Homebrew Cask を更新する

sha256 を確認します。

```sh
cat .build/dist/JoyconMapper-v0.8.0.zip.sha256
```

次のファイルを更新します。

```text
packaging/homebrew/joycon-mapper.rb
```

更新する値:

```ruby
version "0.8.0"
sha256 "<sha256-from-the-file>"
```

tap 側へコピーします。

```sh
cp packaging/homebrew/joycon-mapper.rb ../homebrew-tap/Casks/joycon-mapper.rb
```

tap 側でコミットして push します。

```sh
cd ../homebrew-tap
git add Casks/joycon-mapper.rb
git commit -m "Update Joycon Mapper to 0.8.0"
git push origin main
```

### 8. Homebrew install を確認する

```sh
brew uninstall --cask joycon-mapper
brew untap naoki-mrmt/tap
brew tap naoki-mrmt/tap
brew install --cask joycon-mapper
```

`/Applications` から Joycon Mapper を起動して確認します。

- Gatekeeper 警告なしで起動できる
- アクセシビリティ許可を付与できる
- Joy-Con 入力が表示される
- 左スティックでポインタが動く
- 割り当てたショートカットが発火する
- 左スティック押し込みで左クリックできる
- ZL で右クリックできる
- D-pad で上下左右にスクロールできる
- プロファイルを初期設定に戻せる
- 設定を書き出し、読み込み直して同じ割り当てが復元される
