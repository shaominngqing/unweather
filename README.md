# Murphy

Murphy 是一款面向 Android 和 iOS 的中文天气应用，使用 Flutter 共享界面和业务逻辑。

## 已实现

- 系统真实定位与中文城市、区县解析
- 城市搜索和一键返回当前位置
- 实时天气、24 小时趋势、降水趋势与 10 日预报
- 空气质量、紫外线、日出日落、风向罗盘、体感、湿度、露点、能见度、气压、降水量、云量与阵风
- 本地缓存、下拉刷新、定位权限和网络错误恢复
- 按地点保存多份缓存，启动时先展示缓存并在后台刷新
- 独立天气适配层；温度、体感、空气质量、预警和危险天气保持原值
- 可选接入和风天气官方预警，未配置凭据时自动降级
- Android 与 iOS 权限配置

当前开发版在没有商业天气凭据时使用 Open-Meteo 实时数据。后续可将 `WeatherSource` 替换为和风天气实现，无需改动界面或适配层。

Open-Meteo 免费 API 仅适合符合其条款的非商业用途，正式商业发布前需要确认授权方案。

## 官方天气预警

和风天气预警直接使用 iOS 和 Android 各自的 API KEY。真实 KEY 仅通过编译期参数注入，不要写入源码：

```bash
flutter run -d <iOS设备ID> \
  --dart-define=QWEATHER_API_HOST=你的API_HOST \
  --dart-define=QWEATHER_IOS_API_KEY=你的iOS_API_KEY

flutter run -d <Android设备ID> \
  --dart-define=QWEATHER_API_HOST=你的API_HOST \
  --dart-define=QWEATHER_ANDROID_API_KEY=你的Android_API_KEY \
  --dart-define=QWEATHER_ANDROID_CERT_SHA1=你的Android签名证书SHA-1
```

也可以分别保存在不会提交到 Git 的 `.secrets/qweather-ios.json` 和 `.secrets/qweather-android.json` 中。不要在同一次构建中传入两个平台的 KEY，以免另一平台的 KEY 也进入安装包。

`.secrets/qweather-ios.json`：

```json
{
  "QWEATHER_API_HOST": "你的API_HOST",
  "QWEATHER_IOS_API_KEY": "你的iOS_API_KEY"
}
```

`.secrets/qweather-android.json`：

```json
{
  "QWEATHER_API_HOST": "你的API_HOST",
  "QWEATHER_ANDROID_API_KEY": "你的Android_API_KEY",
  "QWEATHER_ANDROID_CERT_SHA1": "你的Android签名证书SHA-1"
}
```

```bash
flutter run -d <iOS设备ID> \
  --dart-define-from-file=.secrets/qweather-ios.json

flutter run -d <Android设备ID> \
  --dart-define-from-file=.secrets/qweather-android.json
```

请求会按当前平台自动选择对应 KEY。iOS 请求使用和风天气 Web API 要求的 `X-iOS-Bundle-Id` 请求头，默认 Bundle ID 为 `com.murphyweather.murphy`；Android 默认携带包名 `com.murphyweather.murphy` 和当前开发证书 SHA-1。更换正式 Android 签名后，使用 `QWEATHER_ANDROID_CERT_SHA1` 传入正式证书指纹。

未提供 API Host 或当前平台的 API KEY 时，天气功能照常运行，只是不请求官方预警。客户端参数仍可被逆向读取，应在和风天气控制台为两个 KEY 分别设置应用限制、API 限制和合理额度，并定期轮换凭据。

## 运行

```bash
flutter pub get
flutter run
```

指定 iOS 真机：

```bash
flutter devices
flutter run -d <设备 ID>
```

## 质量检查

```bash
flutter analyze
flutter test
flutter build apk --debug
```

## 自动化发布

- 推送到 `master` 会运行格式检查、静态分析和完整测试。
- 推送与 `pubspec.yaml` 版本一致的标签（例如 `v1.0.0`）会构建正式签名的 Android APK/AAB、执行 iOS Release 无签名编译检查，并创建 GitHub Release。
- Android 发布签名与天气凭据保存在 GitHub Actions Secrets，不写入仓库。
- App Store/TestFlight 的可分发 IPA 仍需 Apple Distribution 证书、描述文件和 App Store Connect 权限；CI 中的 `ios-unsigned.app.zip` 仅用于验证，不能直接安装。

首次配置流水线需要以下仓库 Secrets：

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `QWEATHER_API_HOST`
- `QWEATHER_ANDROID_API_KEY`
- `QWEATHER_ANDROID_CERT_SHA1`
- `QWEATHER_IOS_API_KEY`
