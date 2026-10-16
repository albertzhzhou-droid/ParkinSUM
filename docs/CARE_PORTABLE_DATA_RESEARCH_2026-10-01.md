# Care 便携包与单文档恢复研究

这是 W09 的独立 Care 恢复首片。普通用户便携包仍为版本4；新 Care 包为独立格式 `parkinsum_care_portable_data_package` 版本1。没有把普通包改成能够跨存储恢复所有记录的格式。

## 实测缺口与覆盖

修改前实际普通包生产器返回8个文件，其中已有 observations.json，但没有完整 Care 文件。原始观察与预先冻结的验收问题保存在 ignored 的 `build/mega_upgrade/w09_care_portable_research/`。普通包版本2/3/4的 Care 可用性是 `unavailable_in_source_schema`，不能推断为空历史；新包的 `captured_current_local_snapshot` 可以明确包含零条记录。

| 数据 | 普通版本4包 | 独立 Care 版本1包/本次恢复 |
| --- | --- | --- |
| 档案、药物选择、intakes、meals | 既有导出/受限恢复契约 | 不参与本操作 |
| 个人观察 | 可导出；普通恢复仍阻断跨存储记录 | 包含并与其余 Care 一起恢复 |
| 讨论问题、药品讨论、自查、讨论更新 | 无完整 Care 快照 | 全部现有字段和引用保留 |
| follow-up prompts/反馈历史 | 无完整 Care 快照 | 保留原身份、来源、输入摘要与顺序语义 |
| 提醒 | 既有导出和目标同意边界 | 不写入、不自动激活 |

入口在 Care 页面“Care 备份与恢复”。用户先生成并核对计数，再复制或请求浏览器下载；粘贴后检查预览，明确确认合并。相同身份相同内容去重，不同内容拒绝；已有不相关记录保留。普通包不会被当成空 Care 包恢复。中英提供该流程的明确文字，其他语言仍使用英文回退。

## 格式、版本和恢复边界

共享现有 strict JSON lexical/structural reader：8MiB Care 包预算、重复/escaped重复成员、深度/节点/字符串预算先于构造。新格式检查精确字段、版本、同账号 ownerBinding、UTC时间和 sorted-key-json 摘要；之后用真实 CareWorkspaceSnapshot/ledger 解码器验证全部记录、容量、身份、引用、反馈状态和 owner。未来版本、未知字段、损坏身份、错误角色与引用均拒绝。现有 Care 存储schema5及其1–4迁移保持原契约；不推断旧版没有的记录。

只转换顶层 ownerScope、五种记录的 recorderId，以及反馈的 actorId 为 package_owner；同账号恢复后真实 ledger 再核对原 ID。用户文字、prompt input snapshots 和原摘要不做递归替换。包未加密、未签名；SHA用于一致性检查，不能认证来源。稳定 owner 摘要可关联，用户自己输入的文字可能有个人信息；不宣称匿名、所有原始账号字符串均被去除或临床记录完整。

预览冻结原 Care 摘要、目标合并结果和会话epoch；提交时重新读取并核对原摘要，只调用一个 Care 文档的写入。不会顺序调用普通用户状态或提醒写入来制造跨存储部分成功。同一服务队列/一个存储键只是这一支持切片；本轮不宣称跨标签CAS、原生事务、云端恢复或多端协调。W11继续研究实际多标签冲突。

提交前拒绝不写入。平台可能接受写入后丢失确认或会话过期；这不能解释为已取消或数据未保存。页面不显示旧会话的成功；重新读取后可检查已接受状态，再预览同一包，原记录相同则不重复写入。恢复回执仅为进程内确认，尚非 durable restore ledger。

## 已有实际证据与范围

- 服务10项通过：所有七种 Care 类别完整JSON往返、未知状态/剂量、原prompt/feedback身份、已存在内容去重、冲突/过期/容量/确认/授权拒绝、丢失确认后的真实服务读回。
- 页面5项通过：真实AppState中的生成/复制、预览不写入、取消/确认、普通档案及meals不变、源变化失效、退出/同账号重入隐藏旧内容、390×844/200%中英操作。
- 独立 Python 标准库核对实际生产观察的完整原/恢复对象和完整transport对象，只有指定owner字段变化；独立sorted JSON SHA匹配，9个断言全部通过。原观察raw SHA `c3d85e0b87265cd5bdfab65c83efcfc31186aca954a0dfab0f04a2b7a82e85ec`。
- SharedPreferences检查使用真实适配器加mock存储，新服务读回且其余namespace不变；不冒充实际浏览器关闭重开或native持久化。页面复制使用受授权的测试clipboard。
- 初次观察工具误用了没有必填字段的档案构造，页面工具最初未在正确异步上下文关闭对话框、未限定scrollable，以及把保存回执误当bool；原失败保留，工具按实际接口修正。初次分析12处风格问题保留后修正，未删断言或改门禁。

最终冻结目标回归、分析、格式、schema/privacy/语言golden结果记录在本地 `final_targeted_acceptance_receipt.json`，该回单完成前不宣称通过。实际浏览器持久化、多标签、离线重启、原生设备及整候选全量验收继续由W11/W31/W34覆盖；这些不是本页已完成的证据。
