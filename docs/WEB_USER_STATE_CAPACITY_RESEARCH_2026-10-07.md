# Web 个人记录容量升级研究与验收边界

日期：2026-10-07。范围：当前本地升级中的个人记录持久化与 portable package 容量设计。本文记录设计、可复核证据和未完成的验收；不代表公开 GitHub、发布版本或部署已经同步完成。

## 1. 触发问题与方案选择

历史合成实验的 10000 meals + 2000 intakes 持久化，在 `flutter.db.user_state.v1` 遇到 `QuotaExceededError`；完整 portable export 另遇到 500000-node JSON guard。两个失败分别涉及存储后端和传输表示，不能用扩大解析预算或丢弃记录同时处理。原始证据见 [034 persistent report](../build/mega_upgrade/retained_event_diagnostic_persistent_actual_report_034.json)；该报告保留为历史结果，不充当新实现验收。

本次把现有完整个人记录 aggregate 的生产 Web 后端迁至 IndexedDB，同时为内容重复的大 package 引入 schema 5 完整快照去重。完整 state 仍包含 profile、onboarded、active drug selections、meal/intake rows、recoverable event history、已有 onboarding metadata 及 restore receipt；不拆成多个独立提交的数据键。食品、药品、规则目录和其它现有存储不在此次 aggregate 后端迁移范围内。

`shared_preferences` 官方定位为简单键值存储，并明确不给出返回后物理落盘保证。选择 IndexedDB 的依据是事务契约和容量用途；选择本身不证明设备具有固定或无限可用容量。[shared_preferences 2.5.5](https://pub.dev/packages/shared_preferences/versions/2.5.5)、[WHATWG Storage Standard](https://storage.spec.whatwg.org/#usage-and-quota)。

## 2. IndexedDB envelope 与原值保留

[IndexedDbWebUserStateStore](../lib/core/db/web_user_state_store_indexeddb.dart) 使用数据库 `parkinsum.personal-records.v1`、数据库版本 `1`、object store `documents`、record key `user_state`。单条 record 为 JSON string，envelope schema 为 `parkinsum.indexeddb-user-state/1`，只接受以下五个确切字段：

| 字段 | 含义 |
| --- | --- |
| `schema` | envelope 的版本身份 |
| `legacyKeys` | 六个旧键的原 String 值或缺失的 `null` |
| `legacyDigest` | 六键固定顺序 canonical JSON 的 SHA-256 |
| `document` | 当前完整 aggregate JSON string，首次迁移时可为 `null` |
| `documentDigest` | `document` String 或 `null` 的 canonical JSON SHA-256 |

`documentDigest` 覆盖 JSON 编码后的 String 值，和直接对 aggregate 文本字节计算 SHA-256 的用途不同。缺字段、未知字段、损坏 digest 或错误类型拒绝读取，并保留损坏的原 record；仅检查字段数量不足以满足这个契约。

冻结的旧键集合是：

```text
db.active_drugs
db.intakes
db.meals
db.meta.onboarded
db.user_profile
db.user_state.v1
```

迁移保留原 String，不重写其中 JSON 的空白、字段顺序或未知内容，也不把旧值删掉。新 aggregate 的增长不镜像回 localStorage。首次读取先验证旧 aggregate，然后在单个 IDB transaction 中保存冻结旧值和原 aggregate，等待 transaction complete 并完整回读；此后才要求小型 marker `parkinsum.indexeddb.migrated.<databaseName>` 为 `1`。

marker 写入或确认失败时，新 mutation 被拒绝；已提交的原迁移快照和六个旧值保留。marker 已存在而 authoritative record 消失时拒绝从旧快照自动复活数据。marker 与 IDB record 属于不同存储机制，这个顺序策略不是跨机制原子事务。

生产 Web factory 默认选 IDB；IDB 不可用、配额不足或写入失败不会自动回退到旧 aggregate writer。现有 `userStateWriter` seam 和公开 `InMemorySharedPreferencesStore` 保留为显式测试路径，不能与注入的新 store 同时选用。VM 条件导出继续支持既有非浏览器测试语义；这不改变原生数据库方案。

## 3. 排队、事务与旧版本冲突

[WebAppDatabase](../lib/core/db/app_database_web.dart) 将同一 isolate 的个人记录读写同步加入同一 operation queue，避免 `Future.wait(loadMeals, loadIntakes)` 自行争抢 fail-fast Web Lock。参与当前协议的操作在 `parkinsum.persistence.user_state.v1` exclusive lock 内重新读取、验证并写入完整 aggregate；JS 回调保留调用方 Dart Zone。`ifAvailable` 无法即时获得锁时明确拒绝，不暗中转入无协调 writer。该 lock 行为与 [Web Locks API](https://www.w3.org/TR/web-locks/#api-lock-manager) 的契约一致。

实际写入在一个 `readwrite` IDB transaction 内比较完整 expected envelope。只有当前值完全匹配、owner/session authorization 有效、冻结旧键仍匹配，才在 active `get` callback 中同步排入 `put`；不在 get/put 之间等待其它异步工作。成功条件是 transaction `complete` 加完整 raw candidate 回读，不能把 request success 当作整体提交成功。主动 abort 撤销本事务的修改；`strict` durability 是向浏览器提出的偏好。[IndexedDB transaction lifecycle](https://www.w3.org/TR/IndexedDB/#transaction-lifecycle)、[IndexedDB durability hint](https://www.w3.org/TR/IndexedDB/#transaction-durability-hint)。

生产 factory 的同步 legacy reader 只检查 `flutter.` 前缀的六个确切 raw localStorage 键，并按官方 Web 插件的 JSON String 编码还原 String。此应用没有改变 SharedPreferences 默认前缀。locked `shared_preferences_web` 2.4.3 本地来源已核对，官方入口见 [2.4.3 package](https://pub.dev/packages/shared_preferences_web/versions/2.4.3) 和 [Flutter packages implementation](https://github.com/flutter/packages/blob/main/packages/shared_preferences/shared_preferences_web/lib/shared_preferences_web.dart)。

旧版本继续顺序写旧键时，新读取或写入检测冻结摘要不匹配并明确拒绝，保留旧方当前值和 IDB 方记录。active callback 在 put 前及 queued put 后检查 live legacy；transaction complete/readback 后再次检查。边界必须分别表述：

| 被观察到的冲突时机 | 结果 |
| --- | --- |
| active callback 内、提交前 | abort 当前 IDB transaction，保留原 IDB envelope 与发生变化的旧键 |
| 最后同步检查之后、实际提交之后 | 新 candidate 可能已提交；后续检查拒绝报告成功，保留双方，不声称自动回滚 |
| 未参与 Web Lock 的旧版本在另一个 browser agent 写入 | 不能由 Web Lock 阻止；冻结 witness/live checks 提供可检测冲突边界 |

因此，不可宣称“任何旧写都在新数据修改之前被拒绝”。localStorage 与 IndexedDB 没有共同 transaction。SHA witness 检查完整内容一致性，不构成面对同源恶意脚本的授权或防篡改证明。

lost acknowledgment 仍按已有契约处理：异常后回读整个候选 aggregate，只有确切相等且授权仍有效时才认定原提交已经发生，不重复发布相同 mutation。授权在提交后失效可留下原 owner 的已提交值，但不能向过期 session 报告成功。

## 4. 无载荷通知与失效

[change notifications](../lib/core/services/user_state_change_notifications_web.dart) 的 BroadcastChannel 只发送 `null`；兼容 storage-event listener 的 localStorage pulse 使用 `parkinsum.user_state.revision.v1`，值为固定 20 个十六进制字符。信号不携带 owner、record、package、健康内容或完整 state。它触发同源参与者重新确认本地 currency，不提供写入授权。

listener 在首个订阅时建立、最后取消时清理；发送时复用本 tab 的 channel object，避免把自己的成功保存误认成外部修改。标准的广播路径排除发送 object；实际外部 tab 送达仍需独立实验。[HTML BroadcastChannel](https://html.spec.whatwg.org/multipage/web-messaging.html#broadcasting-to-other-browsing-contexts)。

广播或 pulse 失败不撤销已经完成的 IDB transaction，也不授权重复写数据。通知送达与数据 commit 不具有跨机制原子性。该实现属于全局同源失效信号；不能把无 owner/generation payload 的通知描述为绑定特定 owner/generation 的消息。

## 5. Schema 5 保留完整证据的容量路径

[PortableDataCompactTransportService](../lib/domain/usecases/portable_data_compact_transport_service.dart) 以 canonical SHA-256 标识完整 captured food-item snapshot，将重复快照存入 `food_item_snapshots.json`。快照包含 food identity/name/category、tags、所有 nutrient value/unit/missing/status/raw compatibility 字段及 catalog provenance。每次 meal item 使用仍单独携带 quantity；meal time、context、title 和 typed ID 留在每条 row。相同 food ID 但不同 captured missingness 或原值形成不同快照，不能按 food ID 合并证据。

schema 4 普通 package 保留原八文件表示。默认 create 只有在既有 node-capacity guard 命中时才尝试 schema 5；测试也可显式请求紧凑表示。其它字段、深度、String 和 byte guard 不因此放宽。接收方验证 wire integrity 后计算所有引用的完整展开成本，再建立浅层只读 views；共享快照不等于省略其每次使用的逻辑成本。

| 限制 | 当前契约 |
| --- | --- |
| wire package bytes | 原 32 MiB 上限保留 |
| wire lexical/decoded JSON nodes | 原 500000 上限保留 |
| wire JSON depth | 原 24 上限保留 |
| schema 5 logical eight-file expansion nodes | 独立 1200000 上限 |
| schema 5 logical canonical bytes | 独立 32 MiB 上限 |
| schema 5 logical depth | 独立 24 上限 |
| food-item snapshot entries | 独立 25000 上限 |

missing/unknown 保持 unknown；`rawCompatibilityValue: 999` 是保留原兼容数据的 witness，不能被解释为已知营养值。报告零值、未知值、invalid quantity、future time、未指定 dose 分别保留，不因容量优化生成 clinical totals 或 dose inference。

同 owner、`local_user` 的 restore coordinator 先 dry-run inspect/prepare，再核对确切 package bytes digest、原完整 state digest 和显式确认。完整 merge 与 receipt 同处一个 aggregate，receipt 保留 package text、beforeState、before/after digest 和 operation identity。close/reopen 后 Undo 仍需匹配 owner、当前完整 after digest 及 receipt，才能恢复原完整 state；receipt 标为 rolled back。state digest 排除 receipt，以避免 digest 自指。

本次完整恢复实验明确不包含 reminders 或 observations。现有恢复路径对跨 store 的这些非空 records 采取 HOLD，而不是只恢复可支持的部分；不会请求通知权限或启动 reminder。IDB aggregate 的原子性不扩大成 Care/提醒/观察数据的跨 store 原子性。

## 6. 已有证据：按实际执行阶段区分

下面是文档写入时已经落盘的阶段证据。早期结果在之后源码编辑后成为历史结果；不能直接移作最后 candidate 的 qualification。

| 证据 | 已记录结果与限制 |
| --- | --- |
| [focused SDK receipt](../build/mega_upgrade/continuation_20261007/focused_sdk_execution_035.json) | 初次 storage VM：7 PASS；初次 storage Chrome：16 PASS。均发生在后续修复前 |
| 同一 receipt 的 repaired Chrome job | 22 PASS + 1 FAIL；失败为 12k test 初始 guard 拒绝同一 suite 留下的 bounded pulse。整 job 不是 PASS |
| 同一 receipt 的未注册 plugin 独立 12k job | 0 PASS + 1 FAIL，180 秒 timeout；实际平台为 `MethodChannelSharedPreferencesStore`。错误环境证据保留 |
| [static repair review](../build/mega_upgrade/continuation_20261007/storage_repair_and_compact_static_review_035.json) | exact five keys、同 isolate 读写排队和 live legacy 检查的源码修复已只读复核；static review 不代替运行 |
| [registered Chrome log](../build/mega_upgrade/continuation_20261007/storage_12k_registered_actual_chrome_035.log) 与 [interruption receipt](../build/mega_upgrade/continuation_20261007/interrupted_quadratic_matcher_execution_035.json) | 第一项 12k capacity test 已观察到 PASS、全 state reopen 与 cleanup；第二项完整 restore test 未完成，整个 job 为 interrupted/incomplete |

browser unit test 不自动执行应用 plugin registrant。随后两个 12k tests 显式注册官方 `SharedPreferencesPlugin.registerWith(null)`，使用实际 Web localStorage adapter，保留非 InMemory 类型断言并要求 `getInstance`/`reload` 实际成功。这是测试环境注册，不是 mock、生产 fallback 或对旧失败的改写。

已完成的第一项 capacity test 固定 seed `31415926`，硬核对原 Chrome fixture input identity `97db49a275871c8fd1592ff28318a77c0a67400d8390052c74346226b6534eba`。log 中记录 10000 meals、2000 intakes、完整 state UTF-8 大小 7391475 bytes；保存与 reopen 两阶段合计比较 24000 完整 row metadata。旧六键 witness 保持相等，无个人数据镜像回 localStorage，owned DB 和 marker 清理后回读不存在，origin metadata 精确恢复。它使用实际 IDB 的 named synthetic store 注入 WebAppDatabase；default factory 类型仅在不打开生产 DB 的前提下检查。这不能充当真实生产 origin 旧数据迁移或两 tab 实验。

第二项 restore test 的中断 log 已记录 beforePublication refusal 一次、afterQueued actual transaction abort 一次，均核对完整原 state、raw envelope、receipt 状态并经新实际 IDB connection 读取；随后出现 `PortableDataRestore: scoped merge persisted`。这些阶段证据不证明后续完整 state、receipt、re-export、Undo 或最后 cleanup 已完成；没有 final Undo marker，也没有该项测试的 completed PASS。

耗时诊断读到 locked matcher 0.12.20 的 Set equality：对每个 expected element 逐项递归搜索其它集合。对 10000 typed IDs 一次约 50005000 次比较；逐行比较结束后的大型 Set matcher 成为二次方热点。等价修复保留每行完整字段及 SHA、ID 存在和唯一性检查，将最后集合确认改为线性 hash membership/数量确认。同步 JS 忙碌可延迟 timeout 触发，因此中断后 terminal exit code `0` 不证明测试完成。该诊断没有获得可用于性能 qualification 的 profiler profile。

VM 与 Chrome 的 raw fixture JSON identity 不能混用：[独立 runtime review](../build/mega_upgrade/continuation_20261007/fixture_vm_chrome_scope_independent_review_035.json) 保留原 Chrome identity 和实际 VM identity 差异，未把两个 raw hash 相异推断为修改了合成数据，也未证明差异全由数值表示造成。实际 VM producer 已随后完成，并由独立 Node 完整复核，见下一节；focused/full candidate 和真实浏览器持久恢复分别验收。

## 7. 实际新增验收与尚未闭合的部分

### 7.1 VM 大包 producer 与独立 Node 复核

[VM execution receipt](../build/mega_upgrade/continuation_20261007/capacity_fixture_producer_execution_035.json) 记录 session `60474` 已完成并取得 exit `0`，末行 `00:19 +1: All tests passed!`；这是一个实际 VM producer test 的 PASS。[实际报告](../build/personal_log_capacity/035/report-1791421840633769-49053.json) 使用 Dart VM 3.13.0、`macos_arm64`，完整执行生产 default create 的 schema 5 fallback、inspect、typed preparation 与同版本 re-export。输入包含 10000 meals、2000 intakes；报告比较完整原 row 与 prepared row，并确认 re-export 的完整 package bytes 相同。此 producer 没有执行 durable write 或 Undo。

| 实际文件 | 完整文件身份 |
| --- | --- |
| [VM execution receipt](../build/mega_upgrade/continuation_20261007/capacity_fixture_producer_execution_035.json) | 716 bytes；SHA-256 `1bdaa98b4b456a9a71e4297c3a11136acb0e4e93cd289cd09055556d7d0f01c5` |
| [VM producer log](../build/mega_upgrade/continuation_20261007/capacity_fixture_producer_actual_vm_035.log) | 2369470 bytes；SHA-256 `cc39ef80264f3d8ae0192b5d19c410a2d85ba9fe5675caed6478e85c8520f9a6` |
| [VM report](../build/personal_log_capacity/035/report-1791421840633769-49053.json) | 13300 bytes；SHA-256 `fe530f2adedd86d4963e0454f290d380e649adea86511a46cef99d5b6c8a6316` |
| [VM original fixture JSON](../build/personal_log_capacity/035/fixture_input.json) | 7495618 bytes；SHA-256 `523447a7df5cd46c195fbdfb063cb6d10a7fe6253954fb5171c094e69973a228` |
| [实际 schema 5 package](../build/personal_log_capacity/035/fixture.parkinsum.json) | 14100376 bytes；SHA-256 `7bbbddc20c059af63631f75a80975ba663779d75ac1ebc851ff388a6c7a623c3` |
| [独立 Node review](../build/mega_upgrade/continuation_20261007/capacity_artifact_independent_review_035-1791422104915-50481.json) | 65308 bytes；SHA-256 `45cf4445ebfe3c7e18c38b7c62efb6594b86ee787807df2df885358598399fb2` |

独立 Node receipt 为 `actual_artifact_independent_review_pass`：175 个 assertion groups 的 `executedCount` 合计 158170 次已执行断言，全部通过。这不是 175 个 Flutter tests 或 158170 个独立测试案例。它完整读取实际输入、报告和 package，独立复核 wire integrity、展开成本、快照引用、完整合成 row 与 sentinel evidence；其中 Dart restore projection 与 re-export 的执行证据来自 self-bound Dart 报告，Node 没有再次执行 restore coordinator、IDB commit 或 Undo。

实际 package 有九个 wire files、八个 logical files、三个完整 captured snapshots；wire nodes 为 462273、wire depth 为 8，logical nodes 为 933047、logical canonical bytes 为 23713185、完整 envelope logical depth 为 9，均在第 5 节的原 wire guards 与独立 logical bounds 内。原值 sentinel 分别保留 1000 unknown、1000 raw `999`、1000 known zero、1000 invalid quantity、500 future meals、466 future intakes 和 2000 unspecified dose。这些是合成输入完整性检查，不是营养或用药结论。

raw VM input SHA 为 `523447a7df5cd46c195fbdfb063cb6d10a7fe6253954fb5171c094e69973a228`，历史实际 Chrome raw input SHA 为 `97db49a275871c8fd1592ff28318a77c0a67400d8390052c74346226b6534eba`。VM 的 `jsonEncode` raw bytes 包含 `.0` tokens，不能混用两个 raw identity。Node 独立计算的 binary64 scalar-value witness 为 `c31d6f0262f0b191a8ece25b39b8e6b7cffff0bab1c6dcc72f2456a5d1b3081b`，但没有与历史 Chrome 完整 scalar-value witness 做比较，也未证明所有 raw 差异都来自数值编码。因此，VM artifact 的通过不证明该 VM package 可在 Chrome 直接导入；实际 Chrome inspect/prepare/完整持久恢复仍须单独验收。

上述原始文件身份经完整读取并核对读取前后 path/handle metadata 后记录；首次 hydration 导致 metadata 变化的读取被拒绝，只有同一 guard 下稳定重读才采用。未来若同路径产物重新生成，须使用新 receipt 与新完整身份，不能继承这里的 PASS。

### 7.2 三次 debug Chrome 12k job 的实际结局

| 实际执行证据 | 实际结果与完整 SHA-256 |
| --- | --- |
| [首次注册后 log](../build/mega_upgrade/continuation_20261007/storage_12k_registered_actual_chrome_035.log) / [中断 receipt](../build/mega_upgrade/continuation_20261007/interrupted_quadratic_matcher_execution_035.json) | 第一项 observed PASS，第二项中断未完成；整体 `interrupted_incomplete_not_pass`。log：`a749921ee0f1c547e5c9cc21ccafd9e1e652e0fedbdba12f09daf0138940a5a4`；receipt：`2108ad46a0b8c40f6bc9c1e5c7dec9b25bff709175c2f1f694a4bb0789222e7f` |
| [线性集合确认后 log](../build/mega_upgrade/continuation_20261007/storage_12k_linear_actual_chrome_035.log) / [timeout receipt](../build/mega_upgrade/continuation_20261007/linear_restore_timeout_execution_035.json) | session `77702` completed、exit `1`：1 PASS + 1 FAIL，第二项 480 秒 timeout，cleanup 已完成；整体不是 PASS。log：`ba489b4531f34bf794ed4d1e7a47f2b3bef0d729752e4d0be37d70c12e3c3e76`；receipt：`cd6d533b28049d82189011144502ad3dda44acd6a4c8dfde9a89fab00b859e87` |
| [第三次 complete-state helper log](../build/mega_upgrade/continuation_20261007/storage_12k_complete_state_actual_chrome_035.log) | 2378503 bytes；SHA-256 `ffbe500c15637fd7c163107fddaa1bd0c13f05cf23576b365a302166e98a27b9`。末行 `13:44 +1 -1: Some tests failed.`：1 PASS + 1 FAIL，第二项 8 分钟 timeout；整体不是 PASS |

第三次 log 的第一项仍通过真实 IDB 完整保存、重连及清理；10000 meals + 2000 intakes 的完整 state 为 7391475 UTF-8 bytes，SHA-256 `aaae5b67c300240c246b74add70c09857b22208be80a5af2fdb9750659e28a5d`。第二项记录 beforePublication refusal 与 afterQueued actual abort 后完整 preimage 保留，并在 successful scoped merge 后两次核对完整 restored state：7394450 个 canonical String characters，SHA-256 `69130a948ef3ca06fedb2a9fd5b91067e7d86c94c4e9cd71e2999419bf879f0e`。

第二项还记录 Undo 与下一次 connection reopen 后完整 original state：3697 个 canonical String characters，SHA-256 `ebe4fd07d2df1cc7949048715c0c6e0aecd20e29557940af4286b0bb5b85951d`；cleanup 已验证 owned DB/marker 不存在、原 origin metadata 精确恢复。但 `WEB_USER_STATE_12K_PORTABLE_AFTER_UNDO_REOPEN` 末尾 marker 和该 case completed PASS 缺失，timeout 没有撤销为成功。已经到达 Undo/reopen 的阶段证据不等于完整 12k restore 或整体 capacity campaign PASS。

两次 debug timeout 和此前中断都保留为历史失败/不完整证据。后续性能修复或 release 模式运行须重新取得完整结束和自己的 evidence；不能借用 VM producer、第一项 persist PASS 或清理成功来填补第二项的终点。

### 7.3 Default factory 与真实 native quota 的独立尝试

[default factory/native quota log](../build/mega_upgrade/continuation_20261007/default_factory_native_quota_actual_chrome_035.log) 为 4202 bytes，SHA-256 `502224fb467e23465878e26cfcf20a6ce95dd2ac393d082986376ca7f851e372`。session `18577` 已完成、exit `0`，实际计数为 **1 PASS + 2 SKIP**，末行 `00:00 +1 ~2: All tests passed!` 不可改称三个案例通过。

通过的案例显式注册官方 `SharedPreferencesPlugin`，实际 `getInstance`/`reload` 成功；在 headless loopback browser 的严格初始空 localStorage 和空 database metadata 下，按测试 owned 协议使用未修改的 production default factory 与真实六个旧 String。没有注入 live reader。迁移后真实修改旧 key，新读与写都被 live legacy reader 拒绝，完整原 IDB envelope 与新旧方值均保留；清理只删除该空 origin 本次创建的明确 owned keys/DB，并完整验证 origin 和 DB metadata 恢复。这不是用户已有 production origin 的操作，也不是两个实际 tab 并发。

两个 quota 案例在原 8 MiB UTF-16 key/value accounting bound 内未触发真实 `QuotaExceededError`，分别输出 `WEB_NATIVE_QUOTA_HOLD` 并跳过：marker failure 与成功 commit 后 pulse failure 的实际反例尚未取得。初次原生尝试及精确 cleanup 不因后续修改而改写。

后续测试源码 [三个 browser cases](../test/web_user_state_default_factory_browser_test.dart) 已将单个 owned ASCII filler 的 cap 从 8 MiB 调整为 **12 MiB UTF-16 key/value accounting bytes**。原 bound 只允许约 4 Mi 个 Latin characters，本环境实际接受该长度，故扩大隔离工程实验的填充窗口；它不改变 production 存储限额、portable wire/logical bounds 或候选验收标准。仍要求严格初始空 headless loopback origin、单个明确 owned fill key、最多 10000 次 native setItem、实际 native quota error、不 mock 或替换 window API、不 clear 未知键；未能稳定触发则继续 HOLD/SKIP。12 MiB 修改后的新运行已独立完成，结果如下；没有继承旧 attempt 的 PASS。

pulse case 还须捕获实际 production save 的 `WebUserState: legacy change pulse unavailable` 诊断，要求只出现一次，并将实际 diagnostic count 写入 event；捕获仅在该 case 期间保存、代理原 `debugPrint` callback，teardown 恢复原 callback。真实 native quota refusal、实际 product catch diagnostic、完整 commit/readback 和单次 publication 必须同时成立，避免只证明同 key probe 失败而遗漏产品通知仍误通过。此检查没有替换 Storage API、伪造 throw 或修改 production 功能。

实际重跑 session `58281` 已 join、exit `0`，终态 **3 PASS / 0 SKIP / 0 FAIL**。[新完整日志](../build/mega_upgrade/continuation_20261007/default_factory_native_quota_retry_actual_chrome_035.log) 为5653 bytes、SHA-256 `f09240e7b98a41063d7f8f4673ce394d15e3a396f59ef245a21da81455578508`；[执行回单](../build/mega_upgrade/continuation_20261007/default_factory_native_quota_retry_execution_035.json) 绑定实际源码和全部原事件。marker/pulse filler分别实际10470650/10470462 UTF-16 accounting bytes，各26 native setter attempts、15 quota refusals。marker拒绝后完整原状态和六旧String保留，移除唯一owned filler后新完整提交并重连通过；pulse实际production catch diagnostic恰好1次，publication恰好1次、完整新状态重连一致、原sixString不变。三个origin全部精确owned清理，未知key未清除。此结果仍不覆盖两个tab或BroadcastChannel throw。

### 7.4 首次实际 release probe 与独立下载检查

首个实际 diagnostic release build 为 `d169345f-d5d2-4be8-b840-4e1490ab22d0`，采用独立工程入口，未把它当作 `lib/main.dart` 的正式产品构建。2026-10-08 02:09:51 UTC 在 loopback Chrome 实际点击 Run，界面最终显示 `passed` / `completed`，并保留 [终态截图](../build/mega_upgrade/continuation_20261007/capacity_release_actual_chrome_passed_035.jpg)。当次完整 JSON 回单未能从复制接口取得；界面终态本身不代替完整回单和逐阶段独立核对。随后增加正常结果下载按钮和显示文本的 accessibility label，仍须在重新构建后执行新一次全流程。

当次实际 package 下载于 02:14:01 UTC 写入，完整原文件已独立保留为 [Chrome schema 5 package](../build/mega_upgrade/continuation_20261007/actual_chrome_schema5_download_035-20261008T022014Z-8db0b30e-0c26-4668-bdc8-26da7cf6ef6b.parkinsum.json)：20547881 bytes，raw SHA-256 `50af96ece68292861480abde47e1b2e170ed3c1a62d5d5dde10cf8413ce635b5`。[独立实际下载审查](../build/mega_upgrade/continuation_20261007/actual_chrome_download_independent_review_035-1791426276670-84228.json) 为 123 个 assertion groups、234146 次已执行断言，全部通过；这不是 Flutter test 数量，也不补足未保留的完整执行回单。

独立 reader 对九个 wire files 的 integrity、八个 logical files 的展开成本与全部 10000 meals / 2000 intakes 的完整 row keysets 和 binary64 scalar values 做了核对。wire nodes 462273、depth 8；logical nodes 933047、canonical bytes 23494995、depth 9，三个完整 snapshots。unknown、raw `999`、known zero、invalid quantity 各 1000，future meals 500、future intakes 466、unspecified dose 2000 均保留。实际 Chrome rows 与原 VM fixture 和 VM export projection 的逐行 scalar values 相同；七个非 profile logical files 也相同。profile 的 timezone 实际为 `Etc/UTC`，VM 为 `America/Toronto`，因此不声称整个 package 语义完全相同，也不把所有 raw 差异归因于数值编码。独立 lexical sorted canonical identity 与 raw 文件 SHA 分开记录。

原 Downloads 文件的 birthtime/mtime、保留副本和完整严格回读见 [最终 byte retention receipt](../build/mega_upgrade/continuation_20261007/actual_chrome_download_final_byte_retention_035-1791426364161-87681.json)。这些文件只绑定首个实际 probe build，不能改写成后续源码或正式产品构建的执行证据。

### 7.5 新输出接口的完整实际 release 执行

新 diagnostic build `a7677471-5b4c-4f8f-8c01-c6c44155f376` 的 actual root command 已 join、exit `0`；[实际构建与原捕获回单](../build/mega_upgrade/continuation_20261007/capture-exec-20261008T031334123936Z-1d0c96e9cbf3478e96014128614ea8d6-explicit-command-receipt.json) 为6448 bytes、SHA-256 `568019234de228bdf49674586e8a69f25d93e49b7f96ffa67298a440041fcfc0`。它使用独立 diagnostic 入口，仍不充当 `lib/main.dart` 正式界面。新结果下载按钮与完整 accessibility 文本通过正常用户界面取得输出，没有利用 clipboard 空内容或首次界面终态补造报告。

2026-10-08 **03:27:41.139–03:29:04.116 UTC** 实际新运行完成，终态 `passed`。[完整原结果](../build/mega_upgrade/continuation_20261007/actual_release_probe_report_download_035-20261008T033354Z-c418054e-3fae-4d6b-9000-860293b74383.support.json) 为27642 bytes、SHA-256 `797424fbc25958d6372b11fc8999c05da4dfbccbd3af59f96c7c5e8f6758d1a7`；13个实际阶段全部 `completed`，96233次实际求值断言、21个阶段 witness、6个实际 owned IDB connections。计数不是96233个独立测试案例。总预算仍为8分钟，最后30秒留给清理；所有 pending underlying operations 已 join，未降低原完整字段或结束标准。

实际完成：严格空 loopback origin/DB metadata guard、原 fixture pins、官方 preferences getInstance/reload、原2条记录与2条 recovery history、default schema5 create/inspect、完整12000 rows 无写入 preparation、publication 前拒绝与 queued actual transaction abort 两种失败后的完整 preimage、真实 commit/receipt、关闭后新 actual connection 重连、完整12000 incoming typed rows、同schema5全部9 wire files精确重导出、Undo后的完整 original state/receipt与重连、幂等Undo和第二次重连。original/Undo whole-state SHA均为 `ebe4fd07d2df1cc7949048715c0c6e0aecd20e29557940af4286b0bb5b85951d`，restored whole-state SHA为 `69130a948ef3ca06fedb2a9fd5b91067e7d86c94c4e9cd71e2999419bf879f0e`，数量分别1 meal+1 intake与10001 meals+2001 intakes，2条原history及profile/selection/onboarding/receipt一并核对。owned DB/marker实际删除后不存在，before/after DB metadata均为空，origin metadata SHA均为 `44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a`，原origin精确恢复。

03:32:09 UTC实际保存完整report，随后03:33:49 UTC通过正常按钮实际保存**新一次**package。[新实际文件保留](../build/mega_upgrade/continuation_20261007/actual_release_probe_new_package_035-20261008T033832Z-1de40799-2bca-4e3f-994e-da0a37d940c1.parkinsum.json) 为20547881 bytes、raw SHA-256 `50af96ece68292861480abde47e1b2e170ed3c1a62d5d5dde10cf8413ce635b5`。原report先保存，因此其中 `download.status=not_requested` 原样保留；后续 download gateway 的 `actualFileWriteObserved=false` 也不改写。实际文件存在、birthtime/mtime和完整稳定字节由另一个retention receipt证明，不从gateway自行推断。

[新package独立Node审查](../build/mega_upgrade/continuation_20261007/actual_release_new_package_independent_review_035-1791430822289-26259.json) 实际重新执行并 exit `0`：**130 assertion groups、234156次已执行断言**，全部通过。这不是重标首次123groups/234146次旧执行。九个wire files及八个logical files、完整10000 meals/2000 intakes与全部binary64 scalar fields、sentinels、manifest integrity、snapshot references及展开限额重新核对。wire462273nodes/depth8/canonical14080128 bytes，logical933047nodes/canonical23494995 bytes/full depth9，3完整snapshots；raw package、canonical package、content和逐文件域分别保留。当前Chrome package与原VM仅七个非profile logical files语义相同，profile timezone仍为 `Etc/UTC` 对 `America/Toronto`，不声称整个package语义全等或跨runtime canonical bytes相同。

[完整report独立审查](../build/mega_upgrade/continuation_20261007/actual_release_full_report_independent_review_035-20261008T034548Z-19de5764-23f9-4d31-937b-67d46e0a1f21.json) 实际exit `0`，108项独立检查通过；回单96501 bytes、SHA-256 `195281e9abbaa72e640662f1186e5695fc4c042a4d5bf066e271445c7e14b233`。它从原13阶段字段机械求和96233，重算原12000行的JS数值域metadata与individual pins，核对21witness、原/恢复/撤销完整state、6connections、两真实失败、0pending与精确cleanup，并绑定完整public AX JSON与原实际下载报告。首次独立审因root错误汇总96243而拒绝，原拒绝回单保留；仅修正汇总，原报告的逐阶段值不改。独立reader不重新执行浏览器IDB事务，也不把actual named connection reopen扩大为浏览器进程重启。

实际构建前后继续使用未修改的原始 `captureInputs`、完整1754声明输入和四个历史NULL。只读父进程在整个操作期间持有1750个非继承文件句柄，作为读取环境准备；当次成功仍以原始完整capture为准，持有句柄不保证内容持续可用或永久保留。每次原capture后仍核对完整原文件身份，最后全部关闭及恢复当前进程soft nofile。此前metadata guard拒绝、首次select编号超过1024的准备失败和原debug timeout完整保留；改为系统DefaultSelector并修复owned子进程退出/清理，仅属于忽略的执行辅助流程，不放宽原源码guard，也不复制或替换源码。此构建/浏览器执行只证明本段声明的合成release诊断，不是整体候选验收。

### 7.6 冻结前记录的后续验收队列

以下为本文冻结时的检查队列；后续实际结果由 [当前升级结果](MEGA_UPGRADE_RESULTS_2026-09-30.md) 和独立执行回单记录，不能从队列文字推断通过。

1. 最终冻结源码的整体验收须再次独立运行这三个默认工厂/native quota案例，要求3 PASS、0 SKIP、0 FAIL；上面的分项成功不替代整体冻结验收。
2. 最终 frozen candidate 的format、analysis、完整Flutter、Chrome、55个全新门禁、正式产品build、public preflight和release contract仍须按最终job自己的receipt核对；早期各项计数不合并为当前 whole-candidate qualification。
3. 正式 `lib/main.dart` 界面的新增/编辑/实际下载/无写入预览/确认恢复/重开/Undo/重开及真实双tab旧预览失效须重新执行。独立diagnostic入口不代替当前正式产品UI。
4. origin eviction、OS kill或物理durability仍未取得结果。named DB close/reopen不是browser process restart；这些范围若另行开展，须有对应环境、owned数据边界和完整before/after证据。

## 8. 不可扩大解释的边界

- IDB transaction 原子性限于相应 database transaction；没有 localStorage、IDB、notification、Care、reminder 和 observation 之间的共同 commit。
- 同 isolate queue、实际单 tab named DB 重连和 controlled callbacks 不证明真实两个 tab 并发或通知送达。
- transaction complete + 完整 readback 与 `strict` hint 不证明断电、OS kill、物理介质持久性或浏览器永久保留。浏览器仍有实现相关 quota、storage pressure、用户清除与 best-effort eviction 边界。[Storage Standard](https://storage.spec.whatwg.org/#storage-pressure)。
- schema 5 去重和独立 logical bounds 不证明无限规模、低内存、移动设备表现或实际发布 UI 性能；大型同步解析和测试 matcher 的成本必须另行测量。
- 合成 persistence/portable 实验不证明真实患者数据已迁移，也不证明药物摄入、依从性、营养需求、临床有效性或患者安全。

本文不保存可变源码 SHA，也不把本文自身放入自引用 pin。最后 source/build/log identity、公开与本地状态、最终验收结论由冻结后的独立证据记录负责。
