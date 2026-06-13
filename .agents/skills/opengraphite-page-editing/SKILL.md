---
name: opengraphite-page-editing
description: "OpenGraphite リポジトリまたは OpenGraphite project の page / component HTML を編集するときに使う。特に public/、public/_components/、public/locales/、.ogp に登録された pages/components、OpenGraphite のホームページやドキュメントページを更新するときに、ページ編集の思想と判断原則を確認するために使う。"
---

# OpenGraphite ページ編集

OpenGraphite 管理下の page / component HTML を編集するときの思想を示す skill である。ここには実装上の契約や操作手順を置かない。ページ編集時の判断が OpenGraphite の設計思想から外れないようにするためだけに使う。

## 責務の委譲

具体的な契約、操作、検証方法はこの skill では定義しない。必要に応じて次の資料へ委譲する。

- HTML / CSS / runtime / preview / resource の契約: `Docs/specs/SourceOfTruthContract.md`
- CLI / MCP / graph / node edit / diagnostics の契約: `Docs/specs/AgentInterface.md`
- OpenGraphite の設計思想と判断基準: `Docs/specs/DesignPhilosophy.md`
- リポジトリの build / test / quality gate / sample project の扱い: `README.md`
- `OpenGraphite.css`、`data-og-*`、`--og-*`、role、layout、component の説明: `opengraphite-css-contract`

この skill と詳細資料が食い違う場合は、詳細資料を優先する。この skill は方針を思い出すための入口であり、正本の代替ではない。

## 編集思想

- Web 標準の source files を正本として扱う。OpenGraphite のページ編集は、独自の中間表現を作るためではなく、最終成果物になり得る source を直接整えるために行う。
- `public/` のページ編集は、OpenGraphite が実際の Web deliverable を扱えることの自己検証でもある。ホームページやドキュメントページを例外的な手作業の成果物として扱わない。
- OpenGraphite.app、CLI、MCP、browser、AI agent は、同じリポジトリ上の source を見て協業するための入口である。どの入口を使っても、最終的な説明は source files に戻るべきである。
- ページの見た目、構造、文言、preview state、project metadata の責務を混ぜない。便利さのために正本の境界を曖昧にしない。
- 既存機能で自然に編集できない場合は、ページを迂回して壊れやすい例外運用を増やすのではなく、OpenGraphite 側の不足として捉える。
- 不足機能を追加するときは、短期的な作業効率よりも、source-of-truth model、Web 標準としての可読性、リポジトリ上でのレビュー可能性を優先する。
- class や生成物や editor-only state を、OpenGraphite が信頼する主要な編集正本へ昇格させない。
- ページ編集の完了判断は、見た目が一度整ったかではなく、OpenGraphite の正本モデルに沿って継続的に編集、検証、配布できる状態になっているかで行う。

## 判断基準

迷った場合は次の順に考える。

1. 編集後の source files は、そのまま Web 成果物として読めるか。
2. 変更理由と責務境界は、リポジトリ上の資料と source から説明できるか。
3. OpenGraphite の UI、CLI、MCP、AI agent が同じ正本を扱う協業モデルを保てているか。
4. 例外的な手作業ではなく、次回以降も OpenGraphite の経路で自然に編集できるか。
5. 公開リポジトリへ置いても、ユーザー固有情報、生成物の混入、別正本化を招かないか。
