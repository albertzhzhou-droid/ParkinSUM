# W10：偏好与药物选择的会话保存边界

本轮问题是：保存等待期间退出、重新登录或销毁页面时，旧回执是否会修改当前会话。先冻结六个独立预期，再运行现有 AppState，保留原始反例；实现后重新运行相同六例。日期为 2026-10-01；这是软件行为研究，不是云端或临床资格证明。

## 保存协议

每次保存捕获 owner 与会话 epoch。逻辑提交前检查当前会话；档案还必须属于该 owner。档案与药物选择仍先等待持久化回执，再显示成功。登录、退出、重新 bootstrap、清空可见数据及 dispose 会使旧 epoch 失效。

结果区分三个阶段：尚未提交的操作返回 `cancelledBeforePersistence`；已提交且随后收到成功回执的旧操作返回 `committedForPreviousSession`；旧操作的迟到错误返回 `failedForPreviousSession`。后两种结果不会发布旧值、刷新当前建议或显示当前会话的成功提示。它们不表示平台已经接收的写入被取消。协调器的旧 finally 也不会解除新操作的忙碌状态。

Web 保留现有进程内串行写队列，等待前序操作后再次授权，随后才派发平台写入。Native 在真实数据库事务内部检查授权，失效会回滚档案更新或完整药物选择。Firestore 固定原 owner 路径，在读取旧选择后及 batch 提交前检查；选择差异与历史行合入一个 batch。500 条写入是本应用的保守预算，超出时整项拒绝，不拆成可能只写入前缀的多批操作。

Firestore 文档说明 batch 的原子性，但 batch 之前的查询不是事务读，也不构成并发比较交换；离线提交与服务端确认另有边界。[官方事务与批量写入说明](https://firebase.google.com/docs/firestore/manage-data/transactions)。当前配额页列出的每文档 500 次字段变换不能作为通用 batch 文档数上限的证据。[官方配额说明](https://firebase.google.com/docs/firestore/quotas)。W11 的真实多标签并发与存储可用性仍需单独验收。

## 实际检查与限制

- 相同六个 AppState 反例在修复后全部保留当前会话的可见状态；旧操作实际已派发的持久化值仍存在。独立核对结果明确记录 `durable_cancellation_claim: false`。
- 公共会话测试覆盖六种迟到回执、协调器新旧代交接、迟到错误、owner 拒绝及 Web 队列派发前失效。
- 六项 Native 检查通过真实 `/usr/bin/sqlite3` 临时数据库执行 BEGIN/COMMIT/ROLLBACK、插入和删除，并独立读回原值。测试注入数据库打开器，执行生产 NativeAppDatabase 的事务逻辑；没有运行 Flutter sqflite 插件、原生应用或操作系统杀进程旅程。
- 七项 Firestore 检查使用严格记录公开 SDK 调用的离线替身，检查固定 owner 路径、字段、一次完整 batch、预算拒绝和迟到确认。首次六通过一失败来自测试将 `patientId` 误写为 `patient_id`；保留失败日志，修正预期后七项通过。没有连接 Firebase、访问私人账号或验证云端安全规则。

原始预期、实际前后观察和日志保存在忽略的 `build/mega_upgrade/w10_mutation_research/` 与 `/private/tmp/parkinsum-mega-w10-*`；它们不是可发布数据。公开测试位于 `test/preference_session_persistence_test.dart`、`test/native_preference_scope_sqlite_test.dart` 和 `test/firestore_preference_scope_test.dart`。最后的存储组合测试实际 46 项通过；Firestore 七项另行执行，不合并宣称整套项目通过。

本轮不改变数值模型的 22 个实现指纹、临床参数、数据库 schema 12 或便携包 schema。登记的 Native/Web 源码改变需要新配置绑定；八条历史资格记录必须原样保留，新候选继续无签名并阻断发布。完整项目回归、当前 release Web 旅程、真实云端和原生生命周期资格仍待后续验收。
