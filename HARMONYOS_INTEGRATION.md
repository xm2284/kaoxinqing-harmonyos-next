# 考心晴 HarmonyOS 能力接入说明

## 已在工程内完成

- HarmonyOS Symbol：首页快捷入口、底部导航、调节页、我的页和元服务卡片均使用系统 Symbol。
- 原生 ArkUI：Tabs、List、Grid、TextInput、Button、Checkbox、Radio、Toggle、Slider、Progress、Sheet、LoadingProgress 与 Canvas。
- 全场景续接：`EntryAbility.onContinue` 传递压力指数、学习进度、测评进度、目标页签和展开区域。
- 分布式数据：`distributedKVStore` 使用加密存储与 S2 安全等级；本地 Preferences 作为无权限或无分布式设备时的安全兜底。
- 实况窗：呼吸训练开始、更新、暂停和结束均调用 Live View Kit；无权益或设备不支持时自动降级为应用内训练。
- 小艺意图：支持三个 Want Action，并通过 Intents Kit 分享呼吸训练意图。
- 元服务卡片：支持 2x2、2x4，显示考试倒计时、压力状态和学习进度，并从本地/分布式状态刷新。
- 隐私模式：默认开启，本地 CBT 引导不会上传对话；关闭后仅在配置正式服务时请求网络模型。
- 语音输入：Core Speech Kit + AudioCapturer 实时将中文语音转成心语教练输入，按点击行为申请麦克风权限。
- 品牌启动：系统启动图标使用“晴空圆环”标识，随后进入 ArkUI 缩放、旋转和淡入动画。

## 发布前需要在 AGC 完成

### 实况窗

1. 为应用申请 Live View Kit 权益。
2. 注册事件 `kaoxinqing_breathing`。
3. 在获权真机验证胶囊、通知中心和锁屏展示。

工程内的 `LiveViewService` 已处理未获权、设备不支持和服务异常，不会影响呼吸训练本身。

### 小艺意图

在 AppGallery Connect 注册意图：

- 意图名称：`StartBreathingTraining`
- 版本：`1.0.0`
- 建议表达：`开始呼吸训练`、`打开考心晴开始呼吸`、`我想放松一下`
- 唤起 Action：`action.kaoxinqing.breathing`

另外保留以下应用内 Action：

- `action.kaoxinqing.home`
- `action.kaoxinqing.breathing`
- `action.kaoxinqing.pressure`

### 分布式续接

用户在“我的 -> 设置 -> 多端续接”开启功能时，应用会按需申请
`ohos.permission.DISTRIBUTED_DATASYNC`。应在同华为账号、同应用签名的两台真机上验证。

### AI 服务

竞赛演示可在“我的 -> 设置”录入测试用 DeepSeek API Key，密钥只保存于本机 Preferences，
不写入源码且不进入分布式 KV。正式版本仍应由自有服务端保存生产密钥并代理请求。
未配置服务或开启隐私模式时会自动使用本地 CBT 引导，保证离线答辩可用。

## 构建状态

- PreviewBuild：通过
- assembleHap：通过
- 当前产物未签名；发布或真机安装前需在 `build-profile.json5` 配置签名
