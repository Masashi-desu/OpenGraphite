# OpenGraphite Specs

このディレクトリは、OpenGraphite の設計判断を仕様として固定するための文書を置く場所です。

- [DesignPhilosophy.md](DesignPhilosophy.md): OpenGraphite の設計思想、責務分担の原則、判断基準。
- [SourceOfTruthContract.md](SourceOfTruthContract.md): 設計思想を実現するための横断契約。`data-og-*`、`--og-*`、CSS、runtime、preview、resource の正本境界を定義する。
- [AgentInterface.md](AgentInterface.md): `ogkiln` CLI、OpenGraphite MCP server、AI 向け JSON graph、外部変更同期の契約。
- [OgkilnCLI.md](OgkilnCLI.md): `ogkiln` の command、JSON result、編集操作仕様。
- [OpenGraphiteMCP.md](OpenGraphiteMCP.md): OpenGraphite MCP server の resource / tool 仕様。
