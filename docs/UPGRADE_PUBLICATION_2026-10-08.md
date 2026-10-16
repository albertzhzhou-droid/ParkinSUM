# ParkinSUM 升级与发布记录 — 2026-10-08

本次整合以 **Claude 已合并的饮食数据、药品身份数据和冲突引擎**为准。此前 Codex 的本地升级需要与这一基线重新整合、验证后发布；旧版本的通过结果不能作为整合版本的验收结果。

## 1. 权威基线与发布状态

| 范围 | 核对结果 |
| --- | --- |
| GitHub 仓库 | [albertzhzhou-droid/ParkinSUM](https://github.com/albertzhzhou-droid/ParkinSUM) |
| Claude 更新 | [PR #142](https://github.com/albertzhzhou-droid/ParkinSUM/pull/142)，已合并；包含 70 个文件的改动 |
| 刷新后的公开主分支 | `af7ef6981dad160c222c398b4d44946b21c30f8c` |
| Claude 末次提交 | `2a84caa3262276be9e6774e221d5752b04355ede` |
| 本地升级目录 | `github_showcase_upgrade`，原地整合，保留并发改动 |
| 本地已提交 HEAD | `b07c55a952a58f47f1a34835ecd07b712ddad792`；尚未包含上述 Claude 合并 |
| 本地未提交升级 | 完整改动清单与文件内容核对待完成；本次 Git 状态读取超时，不能将空输出解释为工作区干净 |
| 本次整合后的推送 | **待完成**；尚无整合提交或整合后的 CI 结果 |

本表记录 2026-10-08 本轮核对时的状态。已在 GitHub 上的 Claude 更新，与尚未发布的本地修改分别记录。`build/`、下载的合成用户数据包、缓存、操作凭据和其他被忽略的文件不作为源码批量提交。

## 2. Claude 已完成并合并的更新

详细来源、数据定义、再生成方式和限制保留在 [饮食成分及相互依赖研究](FOOD_COMPOSITION_INTERDEPENDENCY_RESEARCH_2026-10-08.md)，本记录只概括最终行为。

### 饮食与营养数据

- 增加 USDA SR Legacy 2018 的 **224 条参考食物记录**，覆盖 16 个食物组，保留来源行、整理元数据、生成器和对照测试。
- 186 条既有种子与区域食物中，**142 条匹配到来源记录，44 条明确保留未知值及原因**。等价与代理匹配分别标注，未知值不填成零。
- FoodData Central 2025-04-24 导入器使用 59 项营养定义，并对照该发布的 477 行 `nutrient.csv` 检查身份、名称、单位和旧编号。
- 区分 by-difference 与 available carbohydrate；只有输入完整时才推导可利用碳水。营养分项不会覆盖总量；单位不一致的数据拒绝映射。
- 保留 Foundation、SR Legacy、FNDDS 与 Branded 的数据类型差异；审计排除的分析样本，保留每份标签营养、来源换算因子、交叉编码与推导方法。

### 药品身份数据

- 保留 RxNorm 2024-12-02 的完整概念块子集、212 条 atoms、生成器和对应测试。
- **18 项目录药品具有已核对的成分身份**；Safinamide、泛称铁补充剂和左旋多巴/苄丝肼三项明确保留未核对原因。
- 增加五项卡比多巴/左旋多巴临床药品目录记录；剂型和释放类型来自来源记录，既有适用性限制继续生效。
- 身份数据及产品强度不是用户剂量，不生成个人服药安排。

### 冲突引擎与配置

- `food_composition_interdependency_model.dart` 接入 mechanistic conflict engine，增加第五个可追溯层。
- 食物内源性 L-dopa、生熟状态歧义及成分恒等式问题可以增加驱动因素、不确定性说明，并降低置信度。
- Claude 的该层保持 `interactionScore`、`severityBand` 和 `interactionType` 不变；不将食物 L-dopa 换算成药物剂量。
- Claude 当前配置为 `2026.10.08-v54`：配置 SHA-256 `48b6ede1c08109c0a2b60af162ebe30fc5e35315257d0cb9999f3c31eacb1427`，来源包 SHA-256 `a4dfcae4d9bb7e47a0d9a6a3451835847c79850af947f0dca0415e4cd5a75bd0`。这些是 Claude 基线身份，不是尚未完成的整合版本身份。

### 工具依赖

Claude 同时更新了现有范围内的 Node 间接依赖，并重新绑定相关报告与隐私合同的文件哈希。整合时保留这些更新，不用旧的本地 lockfile 覆盖它们。

## 3. 此前 Codex 本地升级的接收范围

原计划及结果保留在 [NEXT_UPGRADE_PLAN](NEXT_UPGRADE_PLAN.md)、[MEGA_UPGRADE_EXECUTION_PLAN](MEGA_UPGRADE_EXECUTION_PLAN.md) 和 [此前本地升级结果](MEGA_UPGRADE_RESULTS_2026-09-30.md)。它们描述各自当时的候选版本，不表示全部内容已经发布。

| 本地工作 | 已有结果 | 本次发布要求 |
| --- | --- | --- |
| MEGA-20261002-034 | 历史本地候选：3030 项 Flutter 通过、2 项 Web 专用跳过；109 项 Chrome 通过；55 个验证 gates；公开预检无阻断 | 获取实际未提交文件，保留 Claude 数据与引擎，完成整合后的新验证；不把历史数量转抄为当前通过数 |
| MEGA-20261007-035 持久化 | IndexedDB 提交与重开、旧数据保护、通知失效、跨写入协调及失败处理已实现，并有针对性测试 | 核对文件内容和兼容性，再验证正式应用及双标签页流程 |
| MEGA-20261007-035 可移植数据 | 默认 schema 4 保留；受限的大数据场景使用可选紧凑 schema 5；保留来源快照、导入预览、确认与 Undo | 验证与 Claude 扩展食物/药品记录共存，不能仅凭记录数量宣称内容无损 |
| 12,000 条合成记录容量诊断 | 10,000 条饮食、2000 条用药；13 个发布诊断阶段全部通过；完整报告与实际下载文件已保留 | 该独立诊断不是正式 `main.dart` UI 验收，也不是临床或设备耐久性验证 |

容量诊断的完整报告 SHA-256 为 `797424fbc25958d6372b11fc8999c05da4dfbccbd3af59f96c7c5e8f6758d1a7`；实际下载的紧凑合成数据包 SHA-256 为 `50af96ece68292861480abde47e1b2e170ed3c1a62d5d5dde10cf8413ce635b5`。诊断阶段内机械求和为 96,233 项断言。原始报告不回写；曾出现的统计笔误和失败重试分别保留。

此前本地 v73 与 Claude v54 是不同分支的身份序列。整合不能只替换版本号或照搬任一方的哈希；必须保留历史记录，按实际整合后的来源与行为重新生成当前身份和验证绑定。

## 4. 本次核验与未完成项

### 已核对的公开证据

- [Claude 基线 CI](https://github.com/albertzhzhou-droid/ParkinSUM/actions/runs/37816778647)：`af7ef698…`，completed / success。
- [Claude 基线 Public release preflight](https://github.com/albertzhzhou-droid/ParkinSUM/actions/runs/37816778552)：同一提交，completed / success。
- 上述结果只覆盖 Claude 的公开基线，不覆盖本地未提交升级或未来整合提交。

### 本地发布阻塞

- 本轮 `git status` 达到 45 秒上限，未取得完整结果；读取 `.github/dependabot.yml` 时报告 `Operation canceled`。
- 元数据检查显示多个关键源码、时间线和验证报告仍为 iCloud `compressed,dataless` 占位文件。文件名及长度可见不能代替完整内容读取。
- 必须先完成项目文件的本地下载，再核对改动清单、相关源文件、差异与发布预检。未知或读取不完整的本地内容不得批量提交覆盖 Claude。

### 整合后仍需执行

1. 完整审阅已提交、未提交及被忽略的路径；核对 Claude 70 个改动文件与本地改动的交集。
2. 原地完成合并：饮食数据、药品数据和冲突引擎采用 Claude 当前实现；接收兼容的既有可靠性、导入流程与产品改进。
3. 对实际合并内容执行静态分析、相关测试、配置与报告绑定检查、公开发布预检；根据实际修改确定是否需要完整套件。
4. 对本轮最终实现向 `APP_EVOLUTION_TIMELINE.md` 追加恰好一条记录；已有 Claude 时间线和历史条目保留。
5. 创建可审阅提交并推送 GitHub；核对远端提交、差异与 CI。若主分支需要审查，发布到分支并留下 PR；不强制推送或绕过保护。

## 5. 保留的边界与回退范围

项目仍是教育和研究原型。来源镜像、定义一致性及合成测试不能证明临床效力；未核对身份、缺失营养值、未完成依赖闭包、人类/科学审查、物理设备与操作系统通知等限制按对应文档保留。

回退应按最终提交中的具体路径操作。本记录新增文档可以单独回退；Claude 已合并的 PR #142、既有时间线和未参与本次整合的并发改动不在回退范围内。不得使用整库重置或目录复制回滚。
