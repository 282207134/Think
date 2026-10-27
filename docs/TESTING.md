# 测试与交付记录

验证日期：**2026-10-27（Asia/Tokyo）**。

## 环境

| 项目 | 版本/配置 |
|---|---|
| Flutter / Dart | 3.41.6 / 3.11.4 |
| 主机 | macOS / Apple Silicon |
| 移动端 | Kino API 35，Android ARM64 模拟器 |
| 截图基准 | Flutter 375 × 812 逻辑尺寸、2× 导出 |
| 模拟器视口 | 750 × 1624，density 320 |

## 已完成验证

- `flutter analyze`：无问题。
- `flutter test`：6 项测试通过。
- Android ARM64 Release 与 Web Release 构建成功；Release APK 已在模拟器安装并启动。
- 全量渲染：11 个分类、120 个界面逐一装配页面控件并绘制，无 Flutter 异常；每页生成 PNG 并检查非空输出。
- 邮箱登录：无效邮箱会阻止跳转，有效邮箱与至少 6 位密码可进入动态页。
- 聊天：原生 TextField 发送消息后，本地状态和可见消息同时更新。
- 购物车：数量选择生效，结算能进入支付页；金额由共享状态计算。
- 播放器：播放/暂停与原生进度拖动更新状态。
- 语义回归：只有购物车的 4 个数量控件被识别为计数器，统计数值保持原稿。
- 待办与通知：勾选、切换后，重新加载本地状态仍保留。
- Android 端到端：目录搜索 → 登录 → 动态 → 商城 → 商品详情 → 加入购物车 → 结算 → 支付成功，流程通过并保存 7 张模拟器截图。

这不是与 Pixso 的逐像素自动 diff；截图经过分类总览检查，并针对登录、动态、商城、播放器和统计等页面参考原稿修正了对齐与阴影。全量截图证明渲染覆盖，关键交互和 Android 流程分别验证实际操作。

## 模拟器流程截图

| 阶段 | 实际截图 |
|---|---|
| 分类目录 | [android-01-catalog.png](screenshots/simulator/android-01-catalog.png) |
| 登录 | [android-02-sign-in.png](screenshots/simulator/android-02-sign-in.png) |
| 动态 | [android-03-feed.png](screenshots/simulator/android-03-feed.png) |
| 商城 | [android-04-shop.png](screenshots/simulator/android-04-shop.png) |
| 购物车 | [android-05-cart.png](screenshots/simulator/android-05-cart.png) |
| 支付 | [android-06-payment.png](screenshots/simulator/android-06-payment.png) |
| 成功 | [android-07-success.png](screenshots/simulator/android-07-success.png) |

![Android 商城运行截图](screenshots/simulator/android-04-shop.png)

## 复现

```bash
flutter pub get
flutter analyze
flutter test
flutter emulators --launch Kino_API_35
flutter drive --driver test_driver/integration_driver.dart \
  --target integration_test/app_test.dart -d emulator-5554
```

集成测试仅重置应用自己的 `think.state.v1` 演示键，保证测试数量与截图可重复。模拟器名称和设备 ID 可替换为当前环境中可用的 Android 设备。

```bash
flutter build apk --release --target-platform android-arm64
flutter build web --release
```

全量截图索引：[screenshots/README.md](screenshots/README.md)。

## 平台范围

Android 模拟器流程已运行。Web 已提供发布构建。iOS/macOS 工程随项目交付；本机没有可用的 iOS Simulator runtime，因此没有声称完成 iOS 模拟器运行验证。真实后端、第三方服务和摄像头/地图 SDK 不属于本次 UI 演示的验证范围。

发布包与校验信息：[Android ARM64 APK](../dist/think-android-arm64.apk)、[构建信息](../dist/build-info.json)、[SHA-256](../dist/SHA256SUMS)。

[Release 安装启动截图](screenshots/simulator/android-release-launch.png)。
