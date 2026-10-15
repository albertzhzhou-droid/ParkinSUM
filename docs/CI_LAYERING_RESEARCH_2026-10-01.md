# CI分层与必需检查身份

范围：MEGA W29。本地工作流实现与契约检查；没有push、修改分支保护、远端CI执行或发布。

## 实际读取的保护契约

只读GitHub API观察显示main必需context为`preflight`，GitHub Actions app_id15368、strict=false，继承rulesets数组为空。这是保存回单时的点时观察，不是未来保护状态保证。原回单位于ignored `build/mega_upgrade/w29_ci_research/fresh_remote_required_status_observation.json`。

GitHub要求跨工作流避免同名job，并可能把skipped/neutral视为满足必需状态；因此只保留一个自动`preflight`汇总，且它必须实际检查全部前置结果。[受保护分支官方说明](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)、[job依赖官方说明](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-jobs)。

## 已接入源码的行为

- `ci.yml`仍对全部PR和main push运行。新增快速format/analyze任务；原Flutter checks依赖它但使用always，前置失败时明确失败，不以跳过隐藏失败。
- 自动完整Flutter suite收敛为一次concurrency=2，仍包含全部test/golden/negative与registered-user旅程；移除已包含的单文件重复执行。没有调测试超时或断言。
- 原Node public preflight、Governance gates及Web/Android构建、privacy/NOTICES/CQL/Firestore/default55覆盖保留。依赖缓存只加快准备，所有必需检查命令仍执行。
- `preflight`依赖quick-checks/flutter/node-preflight/governance-gates，always运行并把完整needs传给[严格汇总检查器](../tool/ci_required_status_gate.mjs)。它只接受四个精确job且全部success；缺失、未知、failure/cancelled/skipped/neutral/action_required/timed_out都会失败。
- 原额外整套审计改为workflow_dispatch，并命名Manual release audit，保留其审计命令。自动受保护context保持preflight；没有改远端保护要求。

修改前两份工作流SHA和覆盖要求先冻结，再生成、解析并审阅两份单文件提案，确认基线未变化后应用。没有复制整个工作树或覆盖未交接文件。

## 实际检查与保留失败

六项Node契约实际通过，包括2401种四任务结果组合（只有全成功一组通过）、缺失/畸形/继承/额外字段、真实CLI结果、必需覆盖和受保护context。原检查器漏识别单行`- run:`重复suite的负例真实失败并保留；随后修复识别范围，原负例通过。新增针对核心步骤被if跳过或continue-on-error掩盖的拒绝检查。契约接入现有release:contract，未另建平行门禁。

本地YAML语法解析和有界源码契约不能替代GitHub实际调度。原55门禁的依赖解析两分钟超时仍作为历史失败保留；直接工具及分段计时诊断分别记录，不把它们重命名为原测试或整套验收通过。当前完整候选与远端CI状态分别以实际回单为准。
