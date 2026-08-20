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

和风天气预警使用编译期配置，不要把令牌写入源码：

```bash
flutter run \
  --dart-define=QWEATHER_API_HOST=你的API_HOST \
  --dart-define=QWEATHER_TOKEN=你的JWT令牌
```

未提供这两个参数时，天气功能照常运行，只是不请求官方预警。客户端参数仍可被逆向读取；正式产品若需要长期保密凭据，应通过自己的服务端代理请求。

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
