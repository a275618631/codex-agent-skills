# Contributing / 貢獻指南

## Scope / 範圍

Contributions should improve reusable agent behavior, not encode private workflows or machine-specific settings.

貢獻內容應改善可重複使用的 Agent 行為，不應包含私人流程或特定電腦設定。

## Skill requirements / 技能要求

Each skill must include:

- YAML front matter with lowercase `name` and a precise `description`;
- an English and Traditional Chinese explanation where practical;
- explicit triggers and non-triggers;
- ordered execution steps;
- safety boundaries and approval gates for high-impact actions;
- a clear output contract;
- at least one validation path.

每個技能至少必須具備：小寫名稱、精確描述、中英文說明、觸發與不觸發條件、執行步驟、安全邊界、輸出契約，以及至少一條驗證路徑。

## Pull requests / Pull Request

Run the validator before opening a pull request:

```powershell
pwsh -NoProfile -File .\scripts\validate.ps1
```

Keep pull requests focused. Do not include secrets, credentials, personal paths, exported settings, or unrelated generated artifacts.

PR 應保持單一目的。不得加入秘密、憑證、個人路徑、設定匯出檔或無關產物。
