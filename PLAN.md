# Joy-Con Mapper 実装プラン

## 現状サマリー

### 完了済み
- Rust CLIツールの基本構造実装完了
- Joy-Con (L) のBluetooth検出は成功
- ボタン/スティックのパース処理実装済み
- キーボード/マウス出力 (enigo) 実装済み
- 設定ファイル (TOML) 対応済み

### 問題点
macOSの`gamecontrollerd`がJoy-Conへの**カーネルレベル排他アクセス**を保持しているため、直接HIDアクセス不可。

試した方法:
1. ❌ IOHIDManager (排他モード) → `0xE00002C5` エラー
2. ❌ IOHIDManager (非排他モード) → 同エラー
3. ❌ hidapi crate → 同エラー
4. ❌ GCController framework → Joy-Conを検出せず
5. ❌ gamecontrollerd停止 → SIPにより不可

## 解決策: 仮想HIDデバイス方式

### アーキテクチャ
```
Joy-Con (BLE) → gamecontrollerd → GCController API → joycon-mapper → 仮想HID → macOS
```

### 実装オプション

#### Option A: Karabiner-VirtualHIDDevice (推奨)
- Karabinerの仮想HIDドライバを単独使用
- GitHub: https://github.com/pqrs-org/Karabiner-VirtualHIDDevice
- C APIあり、Rustからバインディング可能
- DriverKit署名済み（インストールのみでOK）

**手順:**
1. Karabiner-VirtualHIDDeviceをインストール
2. Rust FFIバインディングを作成
3. GCController経由でJoy-Con入力を取得
4. 仮想キーボード/マウスに出力

#### Option B: CGEvent API (シンプル)
- macOSのCGEventPostで直接キー/マウスイベント送信
- 仮想デバイス不要
- Accessibility権限必要

**手順:**
1. `core-graphics` crateを使用
2. GCController経由で入力取得
3. CGEventPostでキー送信

#### Option C: Foohid (レガシー)
- 仮想HIDカーネル拡張
- 古いmacOSでのみ動作
- 新しいmacOSでは非推奨

#### Option D: DriverKit (最も複雑)
- Apple純正の方法
- Developer Program加入必要
- 署名とノータリゼーション必要

### 推奨アプローチ

**Phase 1: CGEvent API (即座に試せる)**
```rust
// core-graphics crateでキーイベント送信
use core_graphics::event::{CGEvent, CGEventType};
use core_graphics::event_source::CGEventSource;

fn send_key(keycode: u16) {
    let source = CGEventSource::new(CGEventSourceStateID::HIDSystemState).unwrap();
    let event = CGEvent::new_keyboard_event(source, keycode, true).unwrap();
    event.post(CGEventTapLocation::HID);
}
```

**Phase 2: GCController入力 (要調査)**
GCControllerでJoy-Conが検出されない問題を解決:
- `shouldMonitorBackgroundEvents = true` を設定
- NSNotificationCenterでコントローラー接続を監視
- Joy-Conのボタンを押して「起動」させる

## 次のステップ

### 1. GCController再調査
```rust
// gc_bindings.rsに追加
pub fn set_should_monitor_background_events(monitor: bool) {
    unsafe {
        let cls = class!(GCController);
        let _: () = msg_send![cls, setShouldMonitorBackgroundEvents: monitor];
    }
}
```

### 2. CGEvent出力実装
Cargo.tomlに追加:
```toml
core-graphics = "0.23"
```

### 3. 通知監視実装
```rust
// NSNotificationCenter経由でGCControllerDidConnectを監視
```

## ファイル構成 (現在)
```
joycon-mapper/
├── Cargo.toml
├── build.rs
├── config/default.toml
└── src/
    ├── main.rs
    ├── lib.rs
    ├── error.rs
    ├── cli/
    │   ├── mod.rs
    │   └── commands.rs
    ├── config/
    │   ├── mod.rs
    │   ├── schema.rs
    │   └── loader.rs
    ├── input/
    │   ├── mod.rs
    │   ├── button.rs
    │   ├── joycon.rs      # IOHIDManager実装 (現在blocked)
    │   └── stick.rs
    ├── output/
    │   ├── mod.rs
    │   ├── action.rs
    │   ├── keyboard.rs    # enigo実装
    │   └── mouse.rs       # enigo実装
    └── mapper/
        ├── mod.rs
        ├── engine.rs
        ├── state.rs
        └── transform.rs
```

## 再開時のコマンド

```bash
cd /Users/foxhound/Documents/joycon-mapper

# ビルド
cargo build --release

# デバイス検出 (動作する)
./target/release/joycon-mapper list

# モニター (現在blocked)
./target/release/joycon-mapper monitor
```

## 参考リンク
- Karabiner-VirtualHIDDevice: https://github.com/pqrs-org/Karabiner-VirtualHIDDevice
- core-graphics crate: https://docs.rs/core-graphics/
- GCController docs: https://developer.apple.com/documentation/gamecontroller/gccontroller
- macOS HID: https://developer.apple.com/documentation/hiddriverkit
