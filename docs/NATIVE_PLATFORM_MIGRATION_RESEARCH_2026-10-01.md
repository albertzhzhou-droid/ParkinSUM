# Android 与 Apple 平台迁移研究

这份记录对应 MEGA 的 W32/W33。代码在现有工作树内演进；Android 提醒登记、原生持久化、正式入口、可见通知送达分别验收。阶段收据保存在忽略的 `build/mega_upgrade/platform_research`，完整候选仍需最后的回归与正式 Web 旅程。

## 官方依据与实际插件核对

- [Flutter 内置 Kotlin 迁移](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin)：本机 Flutter 3.47.0 模板使用 Gradle 9.3.1、AGP 9.1.0、KGP 2.4.0。应用移除旧 Kotlin 插件应用与 `kotlinOptions`，使用内置 Kotlin 与 Java 17 目标；`android.newDsl=false` 沿用当前 Flutter 模板。
- [Kotlin 兼容表](https://kotlinlang.org/docs/gradle-configure-project.html)及 [AGP 9.1.0 要求](https://developer.android.com/build/releases/agp-9-1-0-release-notes)支持这一组合。Gradle 全量发行包以官方校验值固定；实际运行 JBR 21，不将运行 JDK 与字节码目标混为一项。
- [Flutter SwiftPM 迁移](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers)：先核对当前安装插件的实际 `Package.swift`，再移除 CocoaPods。iOS 13 个插件中 12 个原生构建插件全部支持；macOS 12 个插件中 11 个原生构建插件全部支持。两者剩余的 path_provider FFI 项没有原生包需求。保留现有 FlutterGeneratedPluginSwiftPackage，分别去除旧 Podfile、锁、框架引用与 xcconfig/workspace 关联，只再生对应 Apple 缓存。
- [Flutter UIScene 生命周期迁移](https://docs.flutter.dev/release/breaking-changes/uiscenedelegate)：iOS 声明单 scene，采用 FlutterSceneDelegate；AppDelegate 实现 FlutterImplicitEngineDelegate，在隐式引擎初始化时注册插件，保留通知中心委托。新建空 iOS 26.2 模拟器用于本轮观察。

## 已观察的 Android 结果

正式 `lib/main.dart` 的 AGP 9 调试 APK 实际构建成功。Flutter 对 firebase_app_check、flutter_timezone 的 KGP 源码扫描告警，以及上游 Java 过时/弃用告警原样保留；成功构建不代表这些告警已经消失。插件实际条件路径与将来 Flutter 的支持情况需分别核对。

专用 emulator-5580 上的开发模式提醒收据 `reminder-20261001235210-b5138184ed30` 通过。来源前后一致，APK 摘要与安装的 base.apk 一致，manifest 和签名完整性通过；插件登记 7 条后清除为 0，隔离测试包已卸载。`visible_delivery_verified=false`、`release_eligible=false`，没有生产签名、真实通知显示或锁屏送达资格。前一次模拟器已退出造成的设备检查失败保留。

## 原生存储与生命周期观察协议

`tool/native_persistence_lifecycle_probe.dart` 仅允许任务自有空 Android/iOS 模拟器与固定隔离标志，拒绝 Firebase、网页、外来运行标记或非空用户记录。Android 复用现有隔离提醒包身份，iOS 使用本轮新建空模拟器。它通过生产 Services、NativeAppDatabase 和 SharedPreferences 实际新增并编辑一条合成餐次，保留两条历史，再用完整规范 JSON 和摘要核对。

在执行前冻结的协议要求每平台三次真实进程冷启动及三次后台恢复：首进程写入标记；后续进程必须读到原标记与全部相同记录；恢复回调重读不得增加记录。局部服务图重建不能替代 OS 进程终止；工程入口不能替代正式入口界面验收。固定本地 civil DateTime 与既有 native 表示一致，不据此宣称 UTC 存储迁移或真机行为。

## 云占位文件导致的失败与读取保护

本轮真实遇到 macOS 云占位文件：文件大小非零，读取却为空或阻塞，影响生成依赖文件、源码和 Git 对象。只请求原路径下载，没有重写原始对象、重置 Git 或复制完整目录。原失败日志保留；仅删除精确的生成 depfile 使构建器重建。

iOS 初次与详细诊断构建实际失败在 Flutter framework 的签名步骤。生成 framework 目录带有 `com.apple.FinderInfo`；Flutter 自身只清理其中二进制的属性，目录属性仍存在。依照 [Apple QA1940](https://developer.apple.com/library/archive/qa/qa1940/_index.html) 仅清除该生成目录的 FinderInfo，保留 fileprovider/provenance 属性，二进制摘要前后一致；没有关闭签名验证或修改 SDK 源码。重试结果单独保留，不覆盖原始失败。

实际重试时云文件提供器再次添加该目录属性。为继续正常签名，把已有 `build/ios` **原子移动**至本机临时缓存，以原位置链接继续访问；macOS 输出使用同一缓存根的独立目录。只有一份生成输出，没有源码、依赖或构建目录副本，没有修改全局 Flutter 配置。精确路径和观察写入 `native_generated_output_location_receipt.json`；这些临时生成缓存不是可发布的原生发行包。

现有验证运行器现在在读取源码和产物前后检查实际字节数、文件身份与修改时间；不完整内容、读取期间替换/删除明确失败，真正零字节文件仍合法。五个新增反例与原运行器/交付器组合共 43 项 Node 测试通过。完整输入摘要的表示没有更改，旧证据不能仅换摘要升级为当前证据。

## 实际原生观察与尚未资格化的部分

iOS SwiftPM 主入口实际构建成功，编译 301.9 秒；三个不同进程均正常显示正式 Initial setup。单独探针构建 51.0 秒；进程 29982、33267、35457 分别读到首次新标记、已有标记、已有标记。随后通过模拟器 Device → Home 实际切后台并重新激活，第三个进程的恢复计数依次为 1、2、3。六条实际统一日志均为完整快照相同、1 餐次/0 用药/2 历史，摘要保持 `a01c8dbfa0298e302b853b75ea35985feb69839ed7a3d14b3d566a070a21e575`；主机读取的整个偏好标记也与首进程一致。工具栏 Home 的即时观察有未变化情况，保留原状态文件并使用实际 Device 菜单/主屏幕图标与后续观察确认，不将按钮尝试当作后台成功。

Android 探针实际构建 72.3 秒。专用隔离包首次不存在，安装后进程 4538、4680、4760 在真实 force-stop/启动间保持同一完整快照，摘要 `ccf2420ac0d14d48fe9d534ef89ee1ef176b368a800c233a9345061eef4dc789`，1/0/2 记录不变。额外的三次 Android 后台恢复尚未观察：当前界面提供器无法绑定该独立模拟器程序。原先更广的两平台生命周期协议明确不是全部通过，没有模拟回调补齐。W32 的有限提醒登记证据与这个额外阶段分别说明。

macOS 首次失败为清缓存后尚未再生的 SwiftPM 汇总包，标准依赖恢复已再生。第二次正常构建被 Xcode 拒绝：既有 keychain entitlement 需要开发证书，本机只读核对为 **0 个有效代码签名身份**。没有删除 entitlement、关闭签名或使用别人的身份，macOS 完整构建及运行仍 HOLD，等待用户已有开发身份；插件 SwiftPM 支持检查本身不能替代这项构建。

SDK 下限使整个 Pub 锁摘要变化，最初 store privacy 检查准确拒绝旧摘要。独立解析证明全部 138 个包对象、Dart 下限、另外三个锁完全相同，只有 Flutter 下限从 3.44 升到 3.47。已同步现有 store privacy 与提醒插件的完整锁摘要；原 privacy 检查随后通过，138 个包/54 个来源主机不变。旧提醒收据保持自己的原始能力矩阵身份，不能改写为新摘要下的执行证据。

后续最终原生收口对应完整输入 `3236a9cffd9d891436a9b281b07a97fbfff4d886b4edfb11e059014e892bd1ba`：正式 main 的 Android/iOS 构建、29 项提醒测试、格式/分析、身份/schema/privacy 均通过。当前提醒实跑 `reminder-20261002010155-32dfa22ac434` 绑定新锁及能力矩阵，实际登记 7→0、隔离包卸载；可见送达和发布资格仍为 false。原生迭代只在 APP_EVOLUTION_TIMELINE 中添加一条 020 收口记录。随后性能入口初始化修复属于新输入，不能替原收据换摘要；完整 Web 旅程及测量另行验收。Web 的真实配额/生产预算 HOLD、未签名临床候选和远端发布边界保持各自原义；Apple iOS 观察不等于 macOS、真机或跨设备资格。
