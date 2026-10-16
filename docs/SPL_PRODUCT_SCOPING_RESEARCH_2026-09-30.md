# SPL 多产品归属研究与实现

日期：2026-09-30。范围：W15；公开标签输入、结构字段、独立预期及生产导入/目录投影。此文不是监管审查或临床资格证明。

## 问题和先验答案

一个 SPL 文件包含多个药品产品时，成分、强度比例、给药途径、剂型和产品编号能否保持在各自产品范围内？文件共用的叙述是否会被错误解释成已确认适用于每个产品的规则？

先阅读 [FDA SPL Implementation Guide，December 2023，Version 1 Revision 202312080859](https://www.fda.gov/media/84201/download?attachment=) 的 2.2.5、3.1、3.2.3 和 3.2.20：产品数据段代码为 48780-1，直接 subject/manufacturedProduct 结构表达产品；成分和途径依附于产品结构。与 [DailyMed SPL resources](https://dailymed.nlm.nih.gov/dailymed/spl-resources.cfm) 交叉定位完整公开响应。实现严格读取 HL7 命名空间及相应代码系统。这里的文档解释只覆盖这些字段和结构。

在修改生产导入器前，于 `2026-09-30T16:12:45.118251Z` 冻结人工预期表；用独立 Python ElementTree 直接结构清单核对，没有读取生产输出来生成答案。固定语料为下列 8 个产品，强度是标签分子/分母比例，**不是实际服药剂量**。

| 完整响应 | 产品 NDC | LEVODOPA，mg / 1 | 另一成分，mg / 1 | 途径 / 剂型 |
| --- | --- | --- | --- | --- |
| SINEMET | 78206-166 | 100 | CARBIDOPA 10 | ORAL / TABLET |
| SINEMET | 78206-168 | 100 | CARBIDOPA 25 | ORAL / TABLET |
| SINEMET | 78206-167 | 250 | CARBIDOPA 25 | ORAL / TABLET |
| SINEMET | 78206-190 | 100 | CARBIDOPA 25 | ORAL / TABLET |
| RYTARY | 64896-661 | 95 | CARBIDOPA HYDRATE 23.75 | ORAL / CAPSULE, EXTENDED RELEASE |
| RYTARY | 64896-662 | 145 | CARBIDOPA HYDRATE 36.25 | 同上 |
| RYTARY | 64896-663 | 195 | CARBIDOPA HYDRATE 48.75 | 同上 |
| RYTARY | 64896-664 | 245 | CARBIDOPA HYDRATE 61.25 | 同上 |

完整响应的来源与实际字节身份：

- [SINEMET SPL XML](https://dailymed.nlm.nih.gov/dailymed/services/v2/spls/9b17b028-964a-473c-823d-81423535bd66.xml)：111,850 bytes，SHA-256 `2de4492865e2515258d013536faf9db3ccaa9799905d3a19f03ad22f57f7feff`。
- [RYTARY SPL XML](https://dailymed.nlm.nih.gov/dailymed/services/v2/spls/6c1f7cd4-de56-45c1-a734-5e77b4aeb6f7.xml)：233,800 bytes，SHA-256 `ba3b6177beb0280ac46e20dfa932fc4ff27b037e248e78a657cf6b9dbe0fd9fe`。

2026-09-30 实际 HTTP 200 XML 采集回单、原响应、独立结构清单、冻结表及修改前后观察保存在 ignored 的 `build/mega_upgrade/spl_product_research/`。公开测试仅保存 `test/fixtures/spl_product_scope/` 下的最小相关字段摘录；其独立预期文件明确记录**摘录 SHA 和完整响应 SHA 不同**。没有把此前 W17 的字段摘录或未知 raw hash 追认成此次完整响应。

## 实际反例和改后验证

修改前生产导入器在两份实际完整响应上分别只返回 1 个 variant、1 个目录药品及 8 条全文件成分信息；这与每份文件独立预期的 4 个产品不符。修改前回单为 `prechange_importer_observations.json`，绑定旧公开输入 `8697283a58c1acc8cf7ea7d93480c8e66756dab07ade716d02015fbdc142702b`。

修改后实际完整响应验证返回每份 4 个产品，合计 8 个独立编号、16 个精确强度比例、每产品各 2 个成分；每份保留一个原始来源文档。强度证据未变成 administration dose。原文件的共用段落继续可读，且其事实没有获得产品适用资格。改后回单 `postchange_full_response_observations.json` 绑定实际 importer/projection 文件 SHA，保留冻结 oracle SHA，不覆盖旧回单。

永久 `test/dailymed_product_scope_test.dart` 另外验证：混合口服/静脉产品与不同成分隔离；同标题/代码段落不覆盖；显式所属段落的事实只归本产品；共用事实留存但不投射成产品规则；有效 NDC 产品重排保持身份；缺失/重复编号、成分身份缺失及未知范围 schema 均 HOLD；缺失途径不推定口服；空产品数据段不制造药品；包装/媒体必须有精确产品编号关联；同编号不同 regulator 不混合。这些反例是合成结构，不能当作官方真实标签的患病或服药数据。

在进一步审查中实际复现两种回退漏洞：产品数据段使用外来 code system，或多个直接产品 subject 缺少规定的数据段代码时，原兼容入口仍会制造一个全文件药品。两个新增反例在修复前均失败；修复后明确保留 source-only HOLD，不能借未解析结构进入旧全文件推断。拒绝检测可读取声明标记，但产品资格仍只由严格命名空间/代码系统解析建立。

## 接入与边界

`dailymed_p0_importer.dart` 保留整份原文 SHA 和 header 版本，新增 raw payload 的 `spl-product-scope/1`；不改数据库表 schema。产品 NDC 与 set ID 分别保留，包装代码不靠 11 位补零猜测归属。缺失/矛盾身份及多个产品数据段保留证据、暂停运行时适用。`cdss_catalog_projection_service.dart` 按产品 variant、jurisdiction 和 regulator 选择范围；未知 schema 不回退全文件事实或成分。目录详情以简短中英文标明未确认的共用段落和身份 HOLD。

目前严格产品结构范围只涵盖所声明的 FDA SPL 路径及上述反例；旧无产品段的扁平 fixture 仍走兼容路径，不能据此宣称任意 XML、全部药品或完整监管验证通过。共用叙述的人工适用审阅、完整包装/图片覆盖、跨来源产品等价、来源使用权判断及临床资格仍没有由这次工程检查建立。配置身份与整套最终验收另由当前候选检查点绑定，旧 release 浏览器结果不能归到这些新增源码。
