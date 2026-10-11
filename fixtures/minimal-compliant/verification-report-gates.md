# 硬校验报告（CI 自动生成 V8.5）
- SkillDir: <SKILL_DIR>
- 时间: 2026-10-03 15:46:19

| 门 | 名称 | 结果 | 证据 |
|---|---|---|---|
| G-INTENT | 意图契约 | PASS | 目标契约四要素齐 |
| G-QUESTION | 提问路由 | PASS | 关键未知均有路由，必要性已判 |
| G-DECOMP | 递归分解 | PASS | 分解到原子单元，无伪动作 |
| G-AUTHORITY | 最高适用权威 | PASS | 主张均解析最高权威与约束力 |
| G-TRUTH | 主张真相 | PASS | CLM↔EVI↔SRC 闭合，独立重建在 |
| G-FRESH | 时效核验 | PASS | 时效类合法，替代链与现场核验齐 |
| G-DOMAIN | 领域闭合/冻结 | PASS | 模型闭合，冻结指纹有效，GAP对拍 |
| G-0 | 完整性 | PASS | R3 文件/frontmatter/节序 齐全 |
| G-ENUM | 封闭枚举/ROLE | PASS | 受控值在枚举内，角色=ROLE-NNN |
| G-SEQ | 序号连续 | PASS | 各类ID 001..N 连续 |
| G-LANG | 语言纯度 | PASS | 外文均中文化/已对照 |
| G-XREF | 交叉引用/决策权 | PASS | 引用闭合，决策权角色均ROLE |
| G-EVIDENCE | 证据字段/URL | PASS | 字段齐，URL均深路径 |
| G-ATOMIC | 原子一来源 | PASS | 原子事实单一主来源 |
| G-QUANT | 定量口径 | PASS | 定量均带口径与出处 |
| G-CURRENCY | 现行/穷尽 | PASS | 三证据齐，状态现行 |
| G-TRACE | 双向追溯 | PASS | RSK均挂SRC，追溯矩阵在 |
| G-KPI | 反虚假指标 | PASS | 指标有口径/窗/来源且含真实业务指标 |
| G-CONTAM | 模板污染 | PASS | 无未登记外来结构 |
| G-DEPTH | 领域深度 | PASS | 特有物=17(ENT6/TOL5/TASK6) 泛化词=2 |
| G-DUTY | 职责分离 | PASS | 分权矩阵在，否决独立 |

结论: DOMAIN_SKILL_GATES_PASS