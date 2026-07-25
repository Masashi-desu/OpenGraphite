# OpenGraphite Specs

このディレクトリは、OpenGraphite の設計判断を仕様として固定するための文書を置く場所です。

- [DesignPhilosophy.md](DesignPhilosophy.md): OpenGraphite の設計思想、責務分担の原則、判断基準。
- [SourceOfTruthContract.md](SourceOfTruthContract.md): 設計思想を実現するための横断契約。`data-og-*`、編集対象 CSS declaration、runtime、preview、resource の正本境界を定義する。
- [CanvasAnnotations.md](CanvasAnnotations.md): `.ogp` 専用の付箋・手書き注釈、canonical world 座標、Sidecar 入力、CLI/MCP、screenshot、成果物非干渉の正本仕様。
- [CanvasObjectReferences.md](CanvasObjectReferences.md): typed node reference ID による任意階層オブジェクトのキャンバス直下配置、ライブ preview、編集同期、永続化境界の正本仕様。
- [AgentInterface.md](AgentInterface.md): `ogkiln` CLI、OpenGraphite MCP server、AI 向け JSON graph、外部変更同期の契約。
- [InspectorDependencyUI.md](InspectorDependencyUI.md): Inspector section 内で標準編集 UI と追加依存性 custom UI を分離・追加するための実装仕様。
- [InspectorValuePresentation.md](InspectorValuePresentation.md): Inspector の値表示と入力手段、および直接操作をプレビュー側へ寄せる操作面の責務境界。
- [OgkilnCLI.md](OgkilnCLI.md): `ogkiln` の command、JSON result、編集操作仕様。
- [OpenGraphiteMCP.md](OpenGraphiteMCP.md): OpenGraphite MCP server の resource / tool 仕様。
