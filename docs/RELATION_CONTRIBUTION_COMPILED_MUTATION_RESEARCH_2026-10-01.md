# 变形关系的有界独立贡献研究

2026-10-01，W22。先冻结4个未在旧采样计划出现的种子、3个可执行分区、6个精确源码变异与5个最小范围试验。随后在同一工作区逐个实际编译源码变异，执行8关系×3分区×4种子。每个变异运行后精确恢复原文件，前后全部96条来源/跟随输入、输出和关系观察一致。全部8运行阶段共768配对、4992次执行器登记API调用，另外保留范围缩减与空cluster辅助实跑；登记计数不冒称动态调用追踪。

| 实际源码变异 | 原96配对中的检出 | 边际贡献/边界 |
| --- | --- | --- |
| 空查询被接受 | 12 | 仅目录输入关系检出 |
| 合成来源可覆盖官方来源 | 12 | 仅来源权威关系检出 |
| 不同scope被合并 | 12 | 仅事实范围关系检出 |
| false改成!true | 0 | 明确的逻辑等价控制 |
| 空cluster状态改变 | 0 | 主生成器未触达；辅助API实际观察到改变 |
| 矛盾解释错误地写成值相同 | 0 | 实际语义存活；分类观察未覆盖原因文本 |

没有将6个变异全部算作检出。三项关系各提供一项已测不同缺陷的边际贡献；另外五项关系在这个变异集内没有新增检出证据。有效参考96条误报0；刻意错误的“不同scope也必须contradiction”关系对12条正确结果误报12。两者都是有限合成集合的计数，不是线上或临床误差率。

不同scope反例在五个实际试验内缩减至一个观察和一个事实；删除唯一事实后该差异消失。保留同scope、相等值不同scope和无关entity控制。只声称本次测试的事实数量最小，不声称全部输入空间最小。生成器前后重放全JSON精确一致，种子与旧计划不重叠。missing/malformed继续原precondition HOLD，没有假造生产执行。

公开工具`tool/run_algorithm_relation_contribution_study.dart`再次运行当前真实API，Node独立评审保留历史编译见证、survivor、未触达分支和原源码摘要；7项负例保护不允许IR变异冒充编译变异、不允许默默宣称存活项等价。已扩展既有`algorithm:contracts:sampling`门禁，没有另建平行验收系统。完整源码变异输出与原日志位于本地忽略目录`build/algorithm_relation_contribution/`及`build/mega_upgrade/w22_relation_research/`；公开fixture仅含压缩见证与完整输出摘要。没有重新进行历史软件资格认证、没有descriptor数量到路径覆盖的换算，也没有算法/临床激活。

## 2026-10-02 current-source campaign

The strengthened incumbent conflict engine changed the source bytes and contradiction explanation after the original campaign. The old v1 witness remains historical and now has an explicit negative test refusing current-source qualification. A new plan froze six exact current-source hunks before execution; each mutant was compiled and run in place, then its original bytes restored before the next phase. The explanation survivor changes the current contradiction explanation, while the scope-collapse, empty-query, synthetic-override, equivalent and empty-cluster mutations preserve their declared purposes. All eight phases produced 96 complete paired observations and 624 API calls each. Independent whole-output review verifies every phase identity, all relations, seeds, partitions, unique pairs, complete pre/post equality, the five auxiliary trials and exact source restoration. Three faulty implementations fail their specific relations in 12 pairs each; equivalent control, explanation survivor and the unobserved empty-cluster branch produce no paired relation failures. Auxiliary executions demonstrate the latter two behavior changes.

Current compressed evidence is `test/fixtures/relation_compiled_contribution_witnesses_v2.json`; original v1 bytes are retained. Full actual observations, mutation plan, execution receipt and independent review are in ignored `build/algorithm_relation_contribution/v71_*_033.json` and `build/mega_upgrade/w22_relation_research/*_033.*`. This remains a bounded experiment: it does not prove general branch coverage, clinical error rates or exhaustive mutation detection. The existing `actual_changed_paired_cases` field counts independently failed relation pairs, rather than every byte-level output difference.
