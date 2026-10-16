# 两类胃模型的合成采样与有限网格可辨识性

范围：MEGA W21。研究只调用两个既有shadow model的[实际结构计算](../lib/domain/usecases/gastric_structural_uncertainty_service.dart)，不改变生产参数、分数或拟合授权。结果是模型层面的有限网格恢复实验，不是人体、临床或连续参数空间的可辨识性证明。

## 先冻结的问题与独立计算

问题：只观察起点、半衰中点或lag前平台，哪些参数无法区分；扩展采样与固定扰动后，粗网格是否隐藏更宽的参数集合。

[粗网格计划](../config/gastric_identifiability_coarse_plan.json)在2026-10-01T05:35:45.038046Z冻结，SHA`d28fbe0a8d23bfc37e112110d62e57b3d4a0ba0adae520157504dd50bffc203e`，早于独立计算和实际Dart比较。粗网格观察后，再于05:38:17.964080Z冻结[细化计划](../config/gastric_identifiability_fine_plan.json)，SHA`b77d3f0d771e28dc5b8668fa4d3cf125c49c6edabc2a61c7e1ab56f4b26f6245`，早于细网格实际计算；它绑定原计划SHA，不能称为在所有早期观察之前已冻结。

- Elashoff定义为`R(t)=exp(-ln(2)*(t/T50)^beta)`，制造真值T50=120min、beta=1.5。粗网格5×6=30，细网格41×51=2091。
- 显式lag指数定义为`t<=L ? 1 : exp(-ln(2)*(t-L)/half)`，制造真值L=30min、half=90min。粗网格5×5=25，细网格61×61=3721。
- 扩展采样为0/30/60/120/180/240min；lag前平台另用0/5/10min。seed31415926固定LCG扰动幅度0.03，并裁剪至[0,1]。它不是概率分布、真实测量噪声模型或置信区间。
- 无扰动最大绝对误差界1e-12；扰动情景界0.03。穷举并保留全部满足界限的网格候选，不使用优化器或声称多起点拟合。

独立Node先生成制造观察和完整候选集合，再调用实际Dart模型。实际生产向量不反向生成标准答案。

## 实际结果与反例

| 采样情景 | Elashoff粗/细保留数 | lag指数粗/细保留数 | 可支持的结论 |
| --- | ---: | ---: | --- |
| 仅t=0 | 30/2091 | 25/3721 | 起点不区分参数。 |
| 中点/lag前平台 | 6/51 | 20/3111 | 中点不区分beta；平台不区分half并保留多个lag。 |
| 六点、无扰动 | 1/1 | 1/1 | 仅在声明网格内唯一。 |
| 六点、有界扰动 | 1/7 | 1/48 | 粗网格的单候选隐藏了细网格中的等价区域。 |
| 网格外制造真值 | 0/0 | 0/0 | 恢复失败仍显示，不宣称找到真值。 |

网格外真值分别为T50=127、beta=1.37和L=37、half=83。保留最小误差候选及其残差，零个合格候选不会转换成成功拟合。

实际Dart共输出42694个参数/时间值，独立Node逐项核对完整网格、时间、值及20组完整保留集合；最大绝对差`1.1102230246251565e-16`，在预先声明的5e-12机器舍入容差内。该容差是软件比较边界，不是生物学误差。两类实际`authorizeFit`均保留`priorFixedOnly`及`synthetic_series_cannot_authorize_fit`。

原观察位于ignored `build/mega_upgrade/w21_identifiability_research/`；原独立预期与后来的实际向量分开保存。完整保留参数组、最小残差、制造真值和固定扰动均可检查。没有删除宽区域、失败情景或改变生产默认值。

## 仓库内再现与门禁

[实际Dart生成器](../tool/run_gastric_identifiability_vectors.dart)、[独立枚举/复核](../tool/gastric_identifiability_experiment.mjs)和[监督入口](../tool/run_gastric_identifiability_check.mjs)接入原`gastric:structures`门禁，55个原门禁身份保持。新报告为`parkinsum.gastric-identifiability-check/1`；粗/细计划及实际向量分别有明确schema。改变schema、截断网格/采样、重复参数、非有限值、值漂移或放宽合成拟合授权都会拒绝。

`npm run gastric:structures`重新产生ignored `build/gastric_identifiability/`当前向量/报告，并绑定实际公共输入和源文件SHA。当前候选的集成执行结果另由实际验收回单记录；上述原独立实验不借用后来的全局源码身份。科学校准、测量效度、连续辨识性、人工评审和临床资格仍未取得。

2026-10-01公开监督入口已实际运行：42694个值与独立计算的最大绝对差仍为`1.1102230246251565e-16`，20组完整集合匹配，报告`pass=true`。该次报告绑定的是执行当时的公共输入；此后文档或源码变动需要重新生成当前候选报告。该项执行不替代完整55门禁、应用全量测试或正式构建验收。
