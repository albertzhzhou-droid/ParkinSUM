# 三个结果入口的有界依赖研究

2026-10-01，W23。冻结三个精确方法声明，不用全文件/descriptor数量替代结果入口：`_MealConflictScoringModel.score`的分数与因子；`GetFoodRecommendationsUseCase.call`的排序、bounded score和特征；`GetProteinTrendUseCase.knownAverageProtein`的已知均值。方法返回计算的直接依赖摘要是本研究的语言子集，不等于逐变量反向数据流。

沿既有Analyzer已解析图中的local_package直接调用追踪，最大深度4、2000声明、20000边。循环去重；外部/SDK、没有已采集本地body的目标、深度截断均列出HOLD。import/export/part仅作为命名空间上下文，不因引入文件就把所有声明算作执行依赖。未解析回调/多态/property/index上下文保持source-unit粒度，不能冒称是已精确归属于该结果的依赖。

配置`config/algorithm_result_sink_study.json`与工具`tool/algorithm_result_sink_slice.mjs`接入既有`algorithm:direct-edge-probe`。精确入口缺失、来源清单不合格或上游解析不合格均失败；6项测试覆盖循环、无关入口排除、深度/预算、未解析callback和import非执行性。首跑因扩展命令未同步精确entrypoint契约被HOLD，原失败保留；同步完整命令后重建实际图，不跳过原检查。

当前三个切片及全部实际目标/边/未解析上下文位于`build/algorithm_result_sink_slice/latest.json`，上游全图保留在`build/algorithm_direct_edge_probe/latest.json`。该结果需要最终输入绑定才能作为当前证据。无论局部结果大小，`closure_complete`恒false；平台插件、动态dispatch、任意外部writer、callback调用闭包和运行时语义分支覆盖尚未闭合。没有从源码可达性推断科学或临床有效性。
