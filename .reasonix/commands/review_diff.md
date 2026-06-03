---
description: 审查 staged diff（pre-commit hook 用）
argument-hint: [diff_text]
---
用中文审查以下的 staged git diff。检查：
1. **正确性** — 是否有 bug、逻辑错误、边界条件遗漏
2. **安全性** — 是否有注入、路径遍历、密钥泄露等风险
3. **可维护性** — 是否有冗余代码、命名不当、缺少注释

如果 **存在问题**，请以一行 `❌ 审查未通过: <简要说明>` **结尾**。
如果 **一切正常**，请以一行 `✅ 审查通过` **结尾**。

staged diff:
```
$ARGUMENTS
```
