# Control Practice

## バージョン付きDMGの作成

リリースタグは `vX.Y.Z` 形式（例: `v1.2.3`）にします。タグを push すると GitHub Actions が macOS アプリと `ControlPractice-X.Y.Z.dmg` を作り、GitHub Release に添付します。アプリの `CFBundleShortVersionString` はタグ、`CFBundleVersion` は Actions の実行番号になります。

```sh
git tag v1.2.3
git push origin v1.2.3
```

タグを使わずローカルで作成する場合は、バージョンを明示します。

```sh
APP_VERSION=1.2.3 scripts/build_dmg.sh
```

macOSのトレーニング画面に、Apple Watchで計測した手首の動きを表示するための連携コードです。

## 実装内容

- `Shared/MotionSample.swift`: MacとWatchで共有するデータ形式
- `WatchApp/WatchMotionManager.swift`: Apple Watchの加速度・回転を計測
- `WatchApp/WatchContentView.swift`: Watch側の計測開始・停止UI
- `WatchApp/WatchConnectivityManager.swift`: WatchからiPhoneへ送信
- `MacApp/MacMotionReceiver.swift`: Mac側で受信して動きの強さを公開
- `MacApp/MotionMonitorView.swift`: 動きの強さ・状態の表示
- Mac側はBonjourサービス`_controlpractice._tcp`（TCP 48521）でiPhoneから受信
- `VideoMotionAnalyzer.swift`: 再生フレームの差分から画面内の動きの強さを算出（フレーム非保存）
- `SceneAnalysis.swift`: 動き量からストーリー・盛り上がり・親密な区間などを参考推定
- 左右の装着腕を選択可能。初回は20サンプル分静止してキャリブレーション

## Xcodeへの追加

この環境ではXcode本体が選択されていないため、プロジェクトファイルの生成・ビルドはまだ実行できません。Xcodeで既存のmacOSプロジェクトを開き、以下のターゲットを追加してください。

1. macOS Appターゲットに `Shared/MotionSample.swift`、`MacApp/MacMotionReceiver.swift`、`MacApp/MotionMonitorView.swift`を追加
2. iPhone Appターゲットに `Shared/MotionSample.swift`、`WatchApp/WatchConnectivityManager.swift`を追加
3. watchOS Appターゲットに `Shared/MotionSample.swift`、`WatchApp/WatchMotionManager.swift`、`WatchApp/WatchConnectivityManager.swift`を追加
4. iPhone AppにWatch Appを埋め込み、WatchConnectivityを有効化
5. WatchターゲットのSigning & CapabilitiesでMotion usage descriptionを追加
6. iPhoneとMacを同じWi-Fiに接続し、iPhoneターゲットのLocal Network権限とBonjourサービス`_controlpractice._tcp`を追加

WatchConnectivityはWatchとiPhoneの間を中継します。Macアプリへ送る部分は既存のiPhone-Mac通信方式に合わせて追加してください。現在の受信クラスはNotificationCenterへ配信するため、既存UIに組み込みやすい設計です。
