# 考心晴 ArkUI-X / Android 迁移准备

## 当前结论

可迁移，但不能把现有 HarmonyOS 工程直接改成 APK 工程。正确方式是在本目录生成独立 ArkUI-X 工程，将可复用的 ArkTS UI 与纯业务逻辑迁入，再为 Android 替换平台能力。原 HarmonyOS 工程始终保留。

## 本机状态

- 已安装 HarmonyOS DevEco Studio 与 HarmonyOS/OpenHarmony SDK。
- 未检测到 ArkUI-X SDK、ACE Tools、Android SDK、ADB 或 Gradle 命令行环境。
- 因此当前不能可靠生成 `.arkui-x/android` 工程，也不能签出可安装 APK。
- 不手写伪造 ArkUI-X 模板；工具链安装完成后使用官方模板生成。

## 预计可直接复用

- ArkUI 页面主体、布局、基础动画、Canvas 图表与资源。
- `DataModels.ets`。
- `MentalHealthAnalyzer.ets`、`SafetyGuardService.ets`、`TinglanAgentService.ets` 等纯业务规则。
- 大部分网络请求与 JSON 模型，但需以 ArkUI-X API 清单实测。

## 需要平台适配层

| 能力 | HarmonyOS 当前实现 | Android 迁移策略 |
| --- | --- | --- |
| 本地数据库 | `relationalStore` | 优先验证 ArkUI-X 插件；不稳定时桥接 Android SQLite/Room |
| 偏好设置 | `preferences` | 验证跨平台插件或桥接 SharedPreferences |
| 页面生命周期 | `UIAbility` | ArkUI-X `StageActivity` / `StageApplication` |
| 振动 | `vibrator` | 跨平台插件或 Android Haptics 桥接 |
| 语音识别 | Core Speech Kit | Android SpeechRecognizer/第三方服务桥接 |
| 实况窗 | Live View Kit | Android 通知/前台服务替代 |
| 小艺意图 | Intents Kit | Android Deep Link/App Actions 替代 |
| 分布式 KV | distributedKVStore | Android 本地缓存 + 后续 AGC 云同步 |
| 服务卡片 | FormExtensionAbility | Android App Widget 单独实现 |
| 电话求助 | Telephony Kit | Android ACTION_DIAL 桥接 |
| 录音播放 | Audio Kit/Core File Kit | 验证插件或使用 Android Media/AudioTrack 桥接 |

## 安全迁移顺序

1. 安装匹配版本的 ArkUI-X SDK、ACE Tools 和 Android SDK。
2. 使用官方模板在本目录生成独立项目，先构建空白 APK。
3. 先迁移 `DataModels` 与纯规则服务并做测试。
4. 迁移基础页面和资源，建立导航。
5. 引入 `PlatformStorage`、`PlatformHaptics`、`PlatformAudio` 等接口，分别实现 HarmonyOS/Android 适配器。
6. 最后迁移语音、实况窗、意图、卡片和分布式能力，Android 不可用功能提供明确降级体验。
7. 完成 Android 模拟器/真机的记录、数据库升级、返回导航、音频和权限回归测试后再签名打包。

## AGC 预留

后续接入 AGC 认证与云数据库可行。建议保留本地数据库作为离线真源，在其上增加账号层、同步队列、冲突解决和删除传播；心理记录属于敏感数据，默认不开启云同步，并提供单独授权、导出和彻底删除能力。
