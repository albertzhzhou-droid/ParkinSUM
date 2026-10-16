# Evidence currency 候选与历史回执持久化 — 2026-10-01

W26 复用已有离线候选面板和原 evidence currency gate。两个候选始终用同一显式 UTC instant 比较，完整保留各自 claim records、registry/snapshot/receipt 摘要和 provider dispositions。保存比较结果不会激活候选规则，也没有在线抓取或来源真实性权限。

## 修改前真实反例

在修改前冻结问题和预期，再用同一独立工程入口于两个全新 localhost 标签执行。底层为真实 SharedPreferences Web 插件；薄转发器只在一次后端写入前设置可控暂停，不以 mock 替代持久化。A 读到空档案后暂停，B 的完整回执实际保存成功，再放行 A。两次均报告成功，但重读只剩 A，B 消失。另一实验在 C 已提交而后端尚未返回时撤销合成会话，随后仍收到 retained-c 成功。

上述两个反例是具体控制时序下的实际生产类行为，不是自然发生频率估计。原源 SHA-256 `17c560598415280724bd35cc971cd02041ceed78184185f48fe9b2a2b0e2258d`，修复后 `23c1ce45a16398b39527c739b35316a48a838eee47505bb6b306b35f05686ee0`；两次实际构建使用精确相同的薄实验源码 `b67ce96097ddea93ea0055e391c95c0daf766903137024b96279d09cd1c4c5f9`。两份构建回单、初态和全部前后事件保存在本地忽略路径 `build/mega_upgrade/w26_currency_research/`。

## 实现与修改后实测

`LocalEvidenceCurrencyComparisonReceiptStore.retain` 在同一 owner 哈希键的锁中执行 reload、解码、去重、容量检查和完整单文档写入，复用 W11 的 origin coordinator。浏览器只在可用安全上下文取得独占 Web Lock 后写入；busy/unavailable 不退回无协调写入。进程内队列释放后移除尾项。写入完成后再次核对会话，已接受的数据留在原 owner 档案，失效会话收到失败，不能以回滚误删他人的随后修改。空/过长/控制字符 owner 拒绝。

修复后同一实验中 B 明确 coordinator-busy，未调用后端也未返回成功；A 完成后 B 重试，两个完整历史快照均保留。C 写入后会话失效返回 session-changed，原 owner 中实际接受的 C 保留。开始新的合成会话后可读取三个完整快照，不改运行时注册表；另一个 owner 读取 0。关闭标签并新开同源标签后仍精确读取 A/B/C，重复保留 B 不产生后端写入或第四条记录。单独 Node 审阅原始 DOM 事件，12 项核对通过，另独立重算外层回执与内层 snapshot SHA-256 并逐项比较完整历史 JSON，不只依赖页面 true 标志。

[W3C Web Locks Working Draft](https://www.w3.org/TR/web-locks/) 说明锁供同一存储范围内参与上下文协作，异步工作完成时释放；此草案及合作锁不赋予账户认证、所有浏览器兼容或防非参与写入的保证。[已锁定 SharedPreferences 2.5.5](https://pub.dev/packages/shared_preferences/versions/2.5.5) 的 README 明确指出多个实例的缓存问题和异步落盘限制。此次保留现有后端并在锁内 reload，未宣称原生跨进程事务或关键数据耐久性。

## 验证、边界与回滚

新增真实生产锁等待、排队撤销后恢复、非法 owner 和 128 条满容量不删除/不部分替换的负例。原服务、面板、origin coordinator 三文件目标组22测试通过，完整代码分析0问题。面板已有 A→B→A 会话与异步历史/保存回执隔离测试保留。原档案schema1、完整receipt版本1和128容量/2MiB上限未改；实际独立核对算法v63配置、147来源摘要、全部12治理完整记录与摘要未变。

实验不等于 OS kill、真实登录账户、原生设备重启、跨设备同步或正式 main 旅程；网络失败没有成为 evidence 当前性的理由。旧结果引用原固定 UTC/snapshot；候选不自动变更运行时。原 DOM 编译错误日志保留，修正 pre 元素构造后才实际构建。最终当前来源验收由结果文档和演进时间线记录。

外科回滚仅限本服务 origin lock/完成后会话核对/owner验证/队列清理、相关测试与本说明。不删除历史回执、不替换原始数据、不撤其他 W11 调用者，不将旧失败重标通过；回滚后重新验收相关来源。
