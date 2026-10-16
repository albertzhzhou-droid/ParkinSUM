# 最终候选的元数据核对

最终检查在完整输入 `49d2bc908f5d0f0261d81db3ec5804258d35c71e6d6830ac8ad116b3dac27fbe` 下实跑 55 门禁，53 通过，算法展示清单和开源来源清单两项失败。原日志、检查点及收据保留；这个候选没有被标记为通过。本次只修正逐项核对后的登记，随后重新冻结输入并验收。

## 算法展示清单

实际编译清单与已登记 JSON 完整比较，只有 `registry_surface_sha256` 和 `manifest_sha256` 不同。65 项算法、14 项固定生产合成追踪、51 项静态契约、完整 provider、界面键、fixture revision 及分类边界完全相同。另一个观察器读取完整登记载荷；独立按源码字面量解析全部 65 项的来源路径、展示键和分类，与编译载荷逐项相同，再用独立规范 JSON 重算两个摘要。新增路径来自此前已验收的营养裁决、目录快照和固定时区规则。

因此只更新当前清单的两个摘要，不增加追踪覆盖或临床资格，不改算法 v63、数值参数、已签名基线或历史治理记录。旧收据继续保留旧身份。

## 报告依赖与字体

来源发现器明确列出两个缺失仓库，没有缺失原仓库，也没有 vendored 目录。保留扫描范围和全部拒绝断言，没有添加排除项。

- 已有 `pdf 3.13.0` 的 [官方发布元数据](https://pub.dev/api/packages/pdf/versions/3.13.0) 的包摘要与锁文件完全相同；[官方 pdf-3.13.0 标签](https://github.com/DavBfr/dart_pdf/tree/0833cd2fc8cf3e62b0228732e81402afca5cc542) 对应明确提交。[固定提交授权文本](https://github.com/DavBfr/dart_pdf/blob/0833cd2fc8cf3e62b0228732e81402afca5cc542/LICENSE) 和实际包授权为 Apache 2.0。`printing 5.15.0` 在同仓库有独立标签提交；没有声称两包源自相同提交字节，或验证了源到包的可重复构建。没有新增依赖。
- 既有中文和阿拉伯语静态报告字体来自 Google Fonts `9710da1eacb3be272583c3224dcb70f9da6eadbb`，[中文家族授权](https://github.com/google/fonts/blob/9710da1eacb3be272583c3224dcb70f9da6eadbb/ofl/notosanssc/OFL.txt) 和 [阿拉伯语家族授权](https://github.com/google/fonts/blob/9710da1eacb3be272583c3224dcb70f9da6eadbb/ofl/notosansarabic/OFL.txt) 与两份本地完整通知逐字节一致。两个二进制摘要符合已有 provenance；独立解析实际 TTF 名称，主家族与 PostScript 名称均为独立 ParkinSUMReport 名称。四个字体/授权文件各有唯一固定摘要记录，原 14 个文件记录保持。
- Google Fonts 集合级许可仍为 `NOASSERTION`；只为上述两个精确家族登记 OFL 1.1，不推导其他集合文件的权限。原 `87a44ad3…` 的 Geist/集合概念记录保留为历史来源。字体整体源码等价性未据摘要宣称。
- [Noto Arabic 的固定版权来源](https://github.com/notofonts/arabic/tree/834a11352b9ee26f827c745757dc380ef8df68bf) 另作 concept-only 引用；版权与 OFL 条款相同，但 FAQ 链接使用 openfontlicense.org，本地 Google Fonts 通知使用 scripts.sil.org/OFL，整文件字节并不相同。两份原文和首次错误等同预期均保留。复制的四文件由 Google Fonts 家族条目持有，没有归到这个仓库或扩大复制权限。

核对后清单为 101 个独立仓库与 18 个字体/授权文件记录。其余原条目完整对象保持不变。新增家族权限越级和 concept-only 分发负例；集合许可、文件级授权、生成通知、未解决临床资产边界继续明确拒绝。

这些是当前本地软件的来源登记和完整性证据，不是外部法律意见、PDF/UA、通用字符覆盖、科学/临床审核、商店审核或公共发布。实际新输入、完整门禁和正式导出结果以唯一时间线及交付回单为准。
