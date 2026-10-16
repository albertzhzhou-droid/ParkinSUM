# 完整65根依赖兼容检查的运行开销

范围：MEGA W02的必需门禁诊断。兼容检查不建立完整结果依赖闭包，也不改变算法资格。原两分钟Flutter测试及其全部65根、session、library URI、diagnostics、canonical ordering断言保持不变。

## 实际失败与分段观察

007同源默认55门禁两次均有54通过/1兼容测试超时；008原单文件测试仍为2通过/1两分钟超时。失败日志与回单保留，没有通过增加超时、跳过根或改成仅语法分析来消除失败。

直接运行原解析器的单次命令约200.780秒，包含启动和编译，不能把它当成函数耗时或据此确定超时原因。另一次默认Dart模式实际分段记录函数98.101443秒，其中界面根`algorithm_visual_projection`的语义解析约69.639秒；首个根约14.209秒。两次执行不同，不能相减推断编译时间，也不能推断Flutter测试的assertions开销。

## 先冻结、后实测的公共API原型

2026-10-01T07:37:44.461930Z冻结未推广原型与判定要求。它唯一改变`AnalysisContextCollection.includedPaths`：由整个lib目录改为manifest中全部65个主库文件的规范绝对路径。每个根仍调用实际`getResolvedUnit`，共享并检查同一个analysis context session，保留结果类型、库身份、URI与所有阻断诊断。

本机锁定analyzer14.1.0的公开构造器明确接收文件或目录的included paths；原型仅使用公开接口，没有调用私有缓存、清除SDK缓存或升级依赖。API语义见[官方AnalysisContextCollection文档](https://pub.dev/documentation/analyzer/latest/dart_analysis_analysis_context_collection/AnalysisContextCollection-class.html)及[官方分析教程](https://dart.googlesource.com/sdk/%2Bshow/126c5fa68064ea21c245ac5f2dd8f3b01a50b24e/pkg/analyzer/doc/tutorial/analysis.md)。本机源码与锁文件是该版本身份依据，网页latest标签不用于推断本机版本。

实际原型函数69.217244秒，65/65兼容接受，完整closure仍HOLD。独立比较确认整个canonical report及全部65条根观察与原实际报告完全相同，摘要均为`e2d21a9c3425c21557ddfd81b1ee4c851f7a53146f023d8143f0145d8bd4e9ff`；两次声明输入均前后稳定。原解析器在原型冻结至推广前内容未变。

这两次是单次默认Dart模式观察，不是性能分布、发布UI测量或原Flutter测试通过证据。只分析全部声明根可减少无关目标调度是本次拟验证的解释；没有证明所有环境下的收益。导入依赖仍由实际语义解析处理，完整结果依赖闭包资格保持HOLD。

## 推广与验收边界

独立完整报告比较通过后，仅将includedPaths的上述hunk推广至现有解析器。原Flutter测试保持原时限和断言重新执行；最终实际结果另记于MEGA结果和迭代时间线，不改写原失败。该工具变更不改变注册算法源码bundle或生产数值参数；完整候选55门禁、整库suite、构建及实际旅程仍需在最终源码上重新验收。

原冻结协议、实际分段报告、独立复核与原型分别保存在ignored `build/mega_upgrade/analyzer_runtime_research/`。回退仅撤销includedPaths hunk，保留原始观察和所有根检查；不复制依赖树或清除个人存储。
