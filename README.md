# Codex Agent Skills｜常用工程工作流程技能庫

[![Validate](https://github.com/a275618631/codex-agent-skills/actions/workflows/validate.yml/badge.svg)](https://github.com/a275618631/codex-agent-skills/actions/workflows/validate.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

排查錯誤、規劃自動化、審查 PR 常常重複同一套步驟。我把這些日常工程實務整理成一組可攜式的 Agent Skills，讓不同專案與 AI Agent 能沿用相同且安全的工作方法。

這組技能將常見的 Agent 互動轉化為明確的執行契約：先診斷再修復、高風險行為設置人工審核閘門、產出結構化證據，並在前提不符或驗證失敗時安全中止。

---

## 精選工程技能 (Skills)

| 技能名稱 | 核心情境與用途 | 輸入與觸發條件 | 具體產出 |
|---|---|---|---|
| [`preventive-repair`](skills/preventive-repair/SKILL.md) | **系統預防性修復與復原邊界**<br>防止盲目嘗試修改造成的二度損壞。先讀取日誌與現況、建立快照備份，再執行單一修復。 | 系統故障、建置中斷、測試失敗或需進行不確定性修補時。 | 根因診斷記錄、最小變更修復步驟、驗證結果與復原計畫。 |
| [`portable-tool-delivery`](skills/portable-tool-delivery/SKILL.md) | **跨機器工具交付與非工程交接**<br>專注於 PowerShell / BAT / CLI 工具在受限 IT 環境、不同編碼與路徑下的可靠執行。 | 工具需要交付至其他電腦、缺乏開發環境或權限受限時。 | 單一入口啟動腳本、環境前置檢查 (Preflight) 與自我診斷報告。 |
| [`workflow-automation-agent`](skills/workflow-automation-agent/SKILL.md) | **受控工作流程自動化與審核**<br>設計具備身分檢查、變更摘要與人工核准閘門的業務自動化流程。 | 涉及多角色簽核、版本發布或跨系統資料流轉時。 | 狀態機流程定義、變更差異摘要、審核通知與不可篡改 Audit Log。 |
| [`pr-review-agent`](skills/pr-review-agent/SKILL.md) | **程式碼審查與缺陷回歸防護**<br>資安優先的 PR 審查。專注於抓出潛在 Bug、回歸風險、缺少測試與敏感資料洩漏。 | 提交 PR、Diff 變更審查或功能重構完成時。 | 缺陷嚴重度清單、邊界條件測試建議、具體改善程式碼區塊。 |
| [`output-contract`](skills/output-contract/SKILL.md) | **標準化任務交付與交接合約**<br>確保多步驟任務完成時具備一致的格式，方便人類閱讀與 Agent 接續。 | 跨 Agent 任務交接、多步驟重構或功能交付前。 | 變更檔案清單、已驗證項目與 Exit Code、未驗證項目與風險提示。 |

---

## 快速開始 (Quick Start)

將需要的技能資料夾直接複製到您的 Agent Runtime 支援的 skills 目錄下即可使用：

```text
skills/
└── preventive-repair/
    └── SKILL.md
```

保持資料夾名稱不變，並在啟用前檢視 `SKILL.md` 內的觸發條件與權限設定。

> [!NOTE]
> 本倉庫為純標準技能庫，絕不包含任何 Token、個人設定、機密金鑰或機器專屬檔案。

---

## 自動化檢驗 (Validation)

本專案提供零外部依賴的 PowerShell 驗證器，可自動檢查 YAML Frontmatter、結構完整性與敏感字詞掃描：

```powershell
pwsh -NoProfile -File .\scripts\validate.ps1
```

---

## 參與貢獻 (Contributing)

歡迎提出改善建議與新技能！請參閱 [CONTRIBUTING.md](CONTRIBUTING.md)。新增的技能應具備獨立自足性、清楚的安全性邊界與停止條件，且能在無私有基礎設施的前提下進行測試。

---

## 安全政策 (Security)

若發現潛在的安全漏洞，請依據 [SECURITY.md](SECURITY.md) 的說明以私下方式回報。切勿在公開 Issue 中張貼憑證、Token 或個人敏感設定。

---

## 授權 (License)

本專案採用 [MIT License](LICENSE) 授權。
