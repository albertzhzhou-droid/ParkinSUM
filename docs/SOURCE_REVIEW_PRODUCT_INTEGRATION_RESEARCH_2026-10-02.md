# 来源复核、当前目录与完整产品细节

2026-10-02，MEGA-20261002-033。本轮延续 NEXT 和全部 35 个 MEGA 工作包；此前候选的验收身份保持历史归属。当前新增流程是本地未提交软件候选，统一最终交付继续进行。

## 研究问题及来源

原始冲突经本地明确选择后，应用应能使用所选数量，同时保留全部替代证据；任何相关原始证据或回单改变，旧缓存不能继续授权该数量。完整品牌产品对象应穿过导入、持久化、目录投影、缓存与详情，而不丢掉未预先列举的字段。

[USDA Branded 官方文档](https://fdc.nal.usda.gov/GBFPD_Documentation/)说明营养值由供应者提交，100 单位基准可能为克或毫升，缺失不等于零，标签舍入可能造成差异，更新不必然表示重新配方。另见[数据类型说明](https://fdc.nal.usda.gov/data-documentation/)对来源类型的区分。因此，本轮展示原始单位、配料、标签值和日期，并保留完整对象；未推断密度、配料数量、产品当前性或浓度换算。2642521 的原始 MLT 仍不凭泛用代码表推断提供者采用的单位命名空间；2385707 的 ml 仍不能作为食用克重。

## 实际实现

- 正式 Import 页接来源差异复核：读取完整 v2 待审包，查看原始数量、方法、范围、来源及完整证据；本地记录人/编号与理由、逐项选择、只读预览、再次确认后原子启用新派生快照。延期和要求更正保留 HOLD。每页 20 项，选择跨页保留。记录人字段不提供认证或临床批准。
- 写入前后检查当前账户及会话代次。离开页面、退出/重建会话、证据改变或最后回单写入失败，拒绝或整体回滚；成功后再刷新目录。原 HOLD、暂存、比较图、决定和历史记录不改写。
- 当前食品目录捕获 10 张表：原生同一 SQLite 事务或 Web 一个完整存储对象。完整原始待审终态不再被旧的 running 暂存标记误判为永远未完成；真正不完整的激活仍拒绝。
- 原始选择必须与当前事实、决定、启用回单、原包、所有参与观察、来源和范围完整匹配，所选值仍来自原观察。添加另一观察、改动未选观察的方法、退休来源或损坏回单均停止计算。仅表行顶层适配器的 _synced_at 可从当前行比较中排除，嵌套原始字段不被删除。
- 应用引导用一致的当前目录覆盖旧缓存，包括新缺失状态。整包 HOLD 时，保留导入缓存中的原始值/证据，取消可计算标记与氨基酸输入。旧内存适配器仍明确标为未经一致读取验证。
- FoodProductEvidence v1 深度冻结完整原始产品对象，序列化和重新载入保留全字段；详情展示品牌、配料、代码、市场、日期、每份原始量、标签营养以及可展开的完整记录。导入营养详情不再截为前 20 项。
- Web 写入队列只在仍有待处理写入时保留 Future；已结束队列释放，错误及排队写入保持串行和回滚约束。

## 当前实际验证与原失败

改动前两个产品路径反例失败：所选 10 g 未进入严格当前目录、完整品牌字段未进入 FoodItem。初次新增界面测试还暴露了错误滚动定位、不可见控件点击和异步上下文遗留；原日志保留，已修正实际界面定位及队列生命周期。测试中两个错误审计字段名和依赖行顺序的断言也已修正，未减少原数值、回滚、缺失或历史断言。

当前相关检查：复核/投影/原子导入/原生 SQLite 42 项通过；中英 390px、200% 字号与产品/原生/详情 19 项通过；一致目录和真实应用引导缓存失效 20 项通过。正式 Import 入口的整库静态检查在发现不存在的账户 getter 后修正为当前会话接口，未以单页测试代替正式入口编译。最终身份、整库回归、Chrome、55 门禁、构建和完整交付由唯一时间线与交付结果记录，不将本节定向通过数拼成整库通过。

目录捕获 schema 2、查询审计 schema 3、产品证据 schema 1；原生 schema 9 和完整 Web 状态 schema 1 不变。新算法配置已前进为 v71，历史 v70 及 19 条完整治理记录保留，新记录仍未批准。独立全对象核对确认：除新身份及其派生完整性摘要外，配置、22 个数值实现/参数、四份实际执行报告以及 41 案例回放保持一致。初次 Python 摘要预测错误地保留了整数小数的 JSON 编码差异；原预测与失败保留，改用与生产规范对应的独立规范编码核对实际 Dart 输出。报告固定摘要首次拒绝旧身份，随后只从独立核对的实际输出前向绑定；最终门禁恢复全部默认校验，不使用摘要打印模式作为验收。

本轮证据限于合成本地复核、两个完整官方品牌对象和所声明软件后端。实际 SQLite 测试使用 SQLite 进程执行本项目原生适配器 SQL/事务及重新打开，不能替代 Flutter 平台插件或操作系统终止测试。没有真人独立审阅、患者/临床验证、真实设备通知送达、产品发布或来源全局当前性证据。

Current observed checks: the first frozen candidate passed analysis and 123 targeted checks. The first Chrome launch had a wrong test filename in the acceptance script; the corrected launch stopped during widget setup with real browser locks. Both attempts remain recorded as failed or interrupted. The UI test now uses Live binding for the real browser event loop and bounded operation waits while preserving actual Web Locks and all original assertions; all 6 UI tests passed in actual Chrome. The complete Foundation archive was executed under v71: all 363 foods, 15,193 source summaries and 17,457 observations match the retained independently checked source output. Whole-candidate acceptance remains pending.

The first serial final gate run completed under input e551025121613e7f6738be847d59f152b7985663a41fab11741cfc044db6eebb: analysis 0 issues, six UI VM checks and 109 actual Chrome checks passed; 53 of 55 gates passed. Schema tests still expected the old 198 surfaces and projection audit v2, and the compiled-relation positive fixture still bound the older conflict source. The corrected schema checks cover all 199 surfaces, immutable product evidence v1, atomic ten-table snapshot v2 and projection audit v3, including drift rejection (32 tests pass). A new eight-phase actual compiled campaign under restored current sources completed 768 paired executions / 4,992 calls. Independent whole-output review detects the three specific faults, retains one semantic survivor and one generator-unobserved branch, and preserves v1 evidence unchanged; all eight review tests pass. All 148 registered source bytes still match v71. The failed final receipt remains preserved, and a new frozen whole-candidate run is required.
