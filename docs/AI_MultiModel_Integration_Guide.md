# AI 多模型整合與 Agent Bridge 技術指南 (單機 PoC 與未來擴展藍圖)

> **文件狀態 (Metadata)**:  
> `status`: Single-User PoC Architecture & Future Roadmap  
> `execution_allowed`: True (單機模式) / False (遠端自動部署)  

---

## 概述

本指南說明將 Gemini 引擎 (Antigravity CLI)、OpenAI/Claude 體系 (Codex CLI) 與本機 LLM (Ollama) 透過 Agent Bridge 與 MCP 進行多模型協同的技術實作。本檔分為：
1. **單人現狀架構與輕量優化**：單機環境實作細節、資源控制與實體驗證矩陣 (Evidence Matrix)。
2. **未來可擴展藍圖**：包含有界 DAG 協作、分散式 Task Envelope、OS 層沙盒與 OpenTelemetry 觀測語意。

---

## 第一部分：單人現狀架構與輕量優化參考

在單人開發情境下，透過輕量級的 Agent Bridge 達成跨 AI 大腦優勢互補。

### 1. 代理人角色與權責實作

| 代理人角色 | 引擎／載體 | 現狀實作職責 | 通訊介面與 MCP 套件 |
| :--- | :--- | :--- | :--- |
| **Antigravity (主控/長脈絡)** | Gemini 3.6 Flash | 架構規劃、長脈絡歷史檢索、主對話介面。 | MCP Client (`mcp_config.json`) |
| **Codex (重構/二審 Worker)** | OpenAI / Custom Adapter | 複雜代碼重構、獨立二審審查。 | `codex mcp-server` (Experimental) & `agent-bridge` |
| **Ollama (本機免費推論)** | Qwen3:8b (Q4_K_M) | 本機離線推導、敏感資料處理、0 雲端 API 帳單。 | `@rawveg/ollama-mcp@1.0.9` (`OLLAMA_HOST: http://127.0.0.1:11434`) |

*說明：Codex 官方將 `codex mcp-server` 標示為 Experimental 介面；若介接 Claude 模型，實務上屬 Custom OpenAI-compatible provider adapter。*

---

### 2. 雙重執行授權模式與安全矩陣

* **唯讀二審模式 (Consult Mode)**：
  - 於獨立暫存區（例如 `%TEMP%\agent-bridge-agy-...`）啟動子行程。
  - 設定 `read-only` 權限，僅分析內容並以 JSON 回傳報告，不修改專案實體檔案。
* **寫入委派模式 (Delegate Mode)**：
  - 傳入專案目標目錄 (`cwd`)，給予 `workspace-write` 權限。
  - 代理人直接於目標目錄實體修改程式碼、執行測試驗證，並回傳 Diff 與結果報告。

---

### 3. 本機實體驗證矩陣 (Evidence Matrix)

本機套件已有獨立單元測試證明實作有效性：

| 宣稱機制 | 實作程式碼檔案 | 測試腳本與命令 | 實測狀態 (Evidence Status) |
| :--- | :--- | :--- | :--- |
| **Windows 進程樹清理** | [cli.py](file://<CODEX_DIR>/mcp/agent-bridge/src/agent_bridge/cli.py#L90-L96) | `python -m unittest test_cli.py` | ✅ 已測試驗證 (`Ran 6 tests OK`) |
| **Log 資安動態遮蔽** | [cli.py](file://<CODEX_DIR>/mcp/agent-bridge/src/agent_bridge/cli.py#L74-L88) | `test_command_redacts_prompt` | ✅ 已測試驗證 (`Ran 6 tests OK`) |
| **排他鎖與 PID 破鎖** | [lock.py](file://<CODEX_DIR>/mcp/agent-bridge/src/agent_bridge/lock.py) | `test_global_lock_is_exclusive` | ✅ 已測試驗證 (`Ran 6 tests OK`) |
| **Ollama 本地預檢** | [server.py](file://<CODEX_DIR>/mcp/agent-bridge/src/agent_bridge/server.py#L16-L23) | 整合至 `health_check` MCP 工具實測 | ✅ 已串接至 health_check 工具通過測試 |
| **環境變數安全白名單** | [cli.py](file://<CODEX_DIR>/mcp/agent-bridge/src/agent_bridge/cli.py#L143-L157) | `test_cli_env_filtering` | ✅ 已實施白名單過濾並通過測試 |

---

## 第二部分：技術精準修訂與未來可擴展藍圖

### 1. 安全沙盒升級藍圖 (Sandbox Evolution)

* **現狀**：採用 `%TEMP%` 暫存目錄與 `read-only` 邏輯參數進行基礎目錄隔離。
* **未來生產級沙盒藍圖 (OS-Enforced Sandbox)**：
  - **Windows 平台**：升級為 Windows AppContainer、ACL 權限限制與受限 Job Object。
  - **Linux 平台**：升級為 Linux Namespace / Docker Container / seccomp / AppArmor。
  - **安全邊界**：實施 Read-only Mount、預設拒絕網路出口、限制 CPU/RAM/PID 額度與獨立低權限作業系統帳號，防止 Sandbox Escape。

---

### 2. 多代理人協作拓撲：有界 DAG 藍圖 (Bounded DAG Topology)

* **現狀**：採用單向單次 (One-Hop) 模式，防範無窮遞迴。
* **未來擴展藍圖 (Beyond One-Hop)**：
  - 允許深層協作，但導入 **有界 DAG (Directed Acyclic Graph) 控制**：
    - **最大深度限制 (Max Depth)**：限制代理人遞迴呼叫層數（如最高 3 層）。
    - **Fan-Out 限制**：限制單一代理人可平行發起的子代理數量。
    - **環路檢測 (Cycle Detection)**：動態檢查呼叫鏈，防止 A ➔ B ➔ A 迴圈。
    - **時間與成本預算 (Budget Allocation)**：每層遞減超時時間與 Token 預算。

---

### 3. 本系統統一 Task Envelope 與 OpenTelemetry 觀測藍圖

#### 🅰️ 內部 Task Envelope 結構 (Internal Contract)
本系統跨 Agent 任務統一採用以下 JSON Envelope 進行通訊：

```json
{
  "schema_version": "1.0",
  "task_id": "uuid-v4",
  "parent_task_id": "uuid-v4-or-null",
  "trace_id": "uuid-v4",
  "idempotency_key": "string-hash",
  "operation": "consult | delegate",
  "requested_scopes": ["repo:read"],
  "deadline": "RFC3339-timestamp",
  "max_tool_calls": 20,
  "approval_required": true
}
```

#### 🅱️ OpenTelemetry (OTel) 語意觀測藍圖
參照並鎖定指定版本的 OpenTelemetry GenAI Semantic Conventions：
* **Traces**：記錄每一步 MCP Tool Invocations、Span 時間與 Agent 轉換節點。
* **Metrics**：追蹤 Tool Call 成功率、Latency 延遲分佈與 Token 消耗量。
* **Logs**：採用結構化 JSON Log，並實施強效 Secret Redaction 預防資安外洩。

---

### 4. 離線推論與 OAuth 憑證邊界釐清

* **Ollama 本地推論邊界**：
  - 鎖定版本 `@rawveg/ollama-mcp@1.0.9`，配置 `OLLAMA_HOST: http://127.0.0.1:11434`。
  - 本機執行可避免雲端模型 API 帳單，但仍有本機電力與硬體運算成本。
  - 僅在停用遙測、限制網路出口、工具純本地化時，達到極致的離線隱私保護。
* **Codex 認證安全規範**：
  - Bridge 透過正式的 CLI 處理與呼叫，**嚴禁 Bridge 程式碼直接解析、讀取或搬移**本機 `~/.codex/auth-config` 或 OS Credential Store 中的 OAuth Token，確保憑證邊界安全。
