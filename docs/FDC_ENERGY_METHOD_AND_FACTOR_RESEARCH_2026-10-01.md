# USDA FDC 能量方法、换算系数与完整归档导入

日期：2026-10-01。范围：来源字段保留和软件反例；未选择新的能量计算方法，未更新生产目录数据。

## 来源与独立预期

[USDA Foundation 文档](https://fdc.nal.usda.gov/Foundation_Foods_Documentation/)将通用 Atwater 和特定 Atwater 能量分别标为 nutrient ID 2047、2048，属于不同计算方法。[官方下载字段说明](https://fdc.nal.usda.gov/docs/Download_Field_Descriptions_Oct2020.pdf)分别定义了按食品归属的能量、蛋白质和脂肪换算系数，以及食品发布日期。这些定义支持保留来源身份，不直接确定本应用应选择哪个方法。

实际取得的官方 ZIP：[Foundation 2026-04-30 JSON](https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_foundation_food_json_2026-04-30.zip)，469303 字节，SHA-256 `186e988ec542e913f51ef62b86a47758e8cdd0d1dc3889e7b055581f3c09c77a`。成员 JSON 6721650 字节，SHA-256 `27d1fe3fd89edfbe528ed915da5619320e1d004d4594603a1b19bdb1511590cc`。原 ZIP 保留在忽略的研究证据中，没有复制完整展开数据树。

**更正早先数量表述：395 是数组位置数，其中 32 个为 null，实际有 363 个食品对象。** 早先采集回单与检查点使用“395 个食品对象”的表述不准确。保留原回单作为历史记录，本文件和新的独立核对记录使用正确计数；不将空位置制造成食品。

完整食品 FDC 1750339（Apples, red delicious, with skin, raw）作为公开测试 fixture 保留，21767 字节，SHA-256 `2dba6f7daf12a45102a7685cfd20f6e249d222c75ae4649a4b9b414f1c194c96`。这是从原成员独立序列化出的一个完整对象，不能称为原成员的字节切片。

原始手工预期于首次 importer 观察及生产修改前冻结：SHA-256 `93d9dd32663208eb2ec848e38794772d62218a2e21ca3bebf8d403cc041c847d`。另外的公开身份/拒绝预期于 2026-10-01T04:24:08.923523Z、生产修改前冻结，SHA-256 `2f1bcc3264bd2d34ec9a71be0438b5253c16dd79beaf1d2aa7168cbae4ddc3f7`。完整归档的独立字段清单在生产修改后、归档探针前由原始 JSON 单独提取；其时间范围不冒充修改前的全归档预期。

## 实际反例与修复

| 实际输入 | 原行为 | 当前实现 |
| --- | --- | --- |
| 完整苹果对象：2047/957 为 61.8 kcal；2048/958 为 55.6 kcal；derivation NC | 金额只在原摘要中，未生成两种方法的观察记录；系数未保留 | 两种独立属性 `energy_atwater_general_kcal` / `energy_atwater_specific_kcal`，各自保留金额、单位、100g edible basis、来源记录与 NC |
| 原 ZIP 中 32 个 null 食品位置 | 实际导入发生 Null→Map 类型转换错误 | 记录原数组位置；导入 363 个对象；非空且不是对象的元素拒绝 |
| CSV 成分行、derivation/source 和三种 factor 表 | 未保留 nutrient/food-nutrient ID、factor join 和 publication string；derivation 的 source_id 未连接 | 保留 ID、source join、原字符串及 parent/factor 原行；食品 owner 不唯一时只保留 HOLD 原始证据 |

不同方法即使金额相同，也不会成为同一测量的重复证据。ID 与 number 冲突、未知 ID 与已知方法 number 冲突、仅有名称、缺少单位或错误单位均不授权方法点。现有 LOQ、负数、无效数值及同方法歧义规则继续适用。

新方法没有填入通用 `FoodItem.energyKcal`，投影证据的 `selected_for_legacy_point_projection` 为 false；食品详情显示各自方法名。单独存在的旧 Energy/208 行仍遵循原策略。把两种方法交给同一冲突 cluster 时，现有引擎返回 `incompatible_cluster`，不会按权威性挑一项或平均。

`nutrientConversionFactors` 按原字段保留，区分缺失、null、空集合和未知 type。JSON 使用原数值，CSV 保留原字符串及 join 来源。它们不变成营养金额，也不触发新的能量、蛋白质或脂肪计算。

食品 publication 字符串按原文保留；例如该苹果仍为 `10/30/2020`。没有推断时区、有效日期、数据新鲜度，也没有用 2026 年下载包标签替代食品日期。JSON ZIP 的 archive/member SHA、原始位置计数和 null 位置保留在来源审计中；候选快照的结构化来源模型仍不保证完整上游发行身份。

## 实际核对范围

- 原单对象前后观察：金额 61.8/55.6、两种方法、单位与基准一致，通用能量保持缺失；不是合成均值或重新计算。
- 当前 16 项新增软件测试涵盖上述边界、投影/JSON roundtrip、独立方法冲突、CSV owner 冲突与 null slot。前次缺单位测试失败来自 fixture 的不可空 Map 类型，修复测试输入后执行；没有放松断言。
- 导入相关组合与完整归档观察实际 124 项通过，范围互有重叠，不能作为整库测试数量。
- 原归档独立清单核对 425 条方法记录（通用 226、特定 199）、363 组系数和日期，零字段差异。95 个食品仍有其单独供应的旧 Energy 点，不意味着为新增方法选择了默认值。
- 第一份归档观察缺 archive metadata 输出，原文件保留。第二次观察使用同一实现补齐观察字段，核对 395/32/363 和原成员摘要；未重写原始失败或第一份观察。

实际证据在 `build/mega_upgrade/fdc_energy_research/`：采集回单、冻结预期、单对象前后结果、完整包第一失败、两份成功观察、独立字段清单和 `bulk_independent_review.json`。这些是忽略的本地证据；公开测试只包含一个完整公开对象和明确的合成负例。

## 保留的后续问题

需要单独研究并冻结方法选择规则，才能让特定或通用 Atwater 结果进入统一点字段。还需区分营养统计、分析样本、来源计算与舍入；换算系数本身不能补足缺失的原始输入或误差模型。完整归档来源保留不等于目录 promotion、每条记录真实性、临床校准或营养建议资格。此前药品未识别、成分角色、产品归属和给药剂量边界继续保持。

本次代码与测试只证明声明的软件和字段范围。当前候选的完整回归、构建和浏览器验收应使用新的源身份；旧检查点证据不改写为新版本。

完整门禁第一次执行时，54 项通过，回放 golden 因仍声明 v57 而失败，原回单保留。独立字节核对证明：只将当前报告的版本和 configuration 摘要回置为旧身份，完整原始 JSON 即与此前 v57 回单的 SHA-256 一致，41 项场景内容未变。Markdown 仅第 6 行变化，因此只更新这一行，不重写场景 digest；随后原有回放 golden 测试通过。该身份比较不等于执行历史软件。最终候选须以此后的完整源码身份重新验收。

最终导入器字节另执行一次原压缩包探针，写入新的 `bulk_actual_importer_observation_v3_final_source.json`。与前次已按原始字段核对的完整观察相比，除实际观察时间外全部字段一致，包括 425 条方法记录、363 组系数和日期以及成员/空占位身份；独立检查见 `bulk_final_source_independent_review.json`。此前失败、缺字段观察及成功观察都继续保留。
