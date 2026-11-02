# Codex Agent Skills｜讓常用工程流程可以重複使用

排查問題、審查程式碼、規劃自動化與交付成果，看似是不同工作，其實常常有同樣的要求：先確認條件、知道哪些操作要核准、留下測試結果，並讓下一個接手的人看得懂。

我把這些工作整理成五個可攜式 Agent Skills。每個 Skill 都是一份可以直接閱讀、調整與放進相容 Agent 環境的工作方法；不用另外架設一套 Agent Framework。

[![Validate](https://github.com/a275618631/codex-agent-skills/actions/workflows/validate.yml/badge.svg)](https://github.com/a275618631/codex-agent-skills/actions/workflows/validate.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## 五個 Skills

| Skill | 什麼時候使用 |
| --- | --- |
| [preventive-repair](skills/preventive-repair/SKILL.md) | 修問題前先找出失效原因、影響範圍與復原方式，避免補一個洞又出現另一個 |
| [portable-tool-delivery](skills/portable-tool-delivery/SKILL.md) | 要把腳本或工具交給另一台電腦、另一個作業系統或非工程使用者時 |
| [workflow-automation-agent](skills/workflow-automation-agent/SKILL.md) | 把人工流程變成自動化，包含輸入檢查、重複事件、核准與失敗復原 |
| [pr-review-agent](skills/pr-review-agent/SKILL.md) | 檢查 PR 的功能正確性、回歸風險、安全問題與測試缺口 |
| [output-contract](skills/output-contract/SKILL.md) | 任務結束時需要留下實際修改、驗證結果與下一步，而不是只說「完成」 |

## 實際使用情境

例如要將「收到新版設備文件 → 比對版本 → 交由負責人審核」改成自動化：

1. 用 `workflow-automation-agent` 列出事件來源、資料條件、核准節點與失敗處理。
2. 實作完成後，讓 `pr-review-agent` 檢查修改是否破壞既有流程，並找出未測試的狀態。
3. 交付時套用 `output-contract`，讓執行結果、測試與待辦留下清楚紀錄。

Skills 提供的是可重用的操作規則；能否讀檔、執行程式或呼叫外部服務，仍取決於使用它的 Agent 平台與權限。

## 如何使用

挑選需要的 Skill，把整個資料夾複製到目標 Agent 平台支援的 Skills 位置，保留 `SKILL.md` 與附屬檔案。啟用前先閱讀每份 Skill 的適用條件。

```text
skills/
├── preventive-repair/
│   └── SKILL.md
└── pr-review-agent/
    └── SKILL.md
```

## 驗證技能格式

倉庫附有 [PowerShell 檢查工具](scripts/validate.ps1)，可檢查 Skill 目錄、front matter、必要段落與常見敏感檔案模式。

```powershell
pwsh -NoProfile -File .\scripts\validate.ps1
```

新增或修改 Skill 時，可以先執行檢查，再送交 PR 審查。完整貢獻方式見 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 安全與授權

這些 Skills 不包含私人憑證或特定電腦的設定備份。如發現安全問題，請依 [SECURITY.md](SECURITY.md) 私下回報，不要將敏感資料放進 Issue。

授權：MIT，© 2026 a275618631。
