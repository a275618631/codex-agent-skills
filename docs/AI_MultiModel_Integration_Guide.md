# 三模型 (Antigravity / Codex / Ollama) 跨架構整合與雙向控制技術指南

## 概述

本文件記錄將 Gemini 引擎 (Antigravity CLI)、OpenAI/Claude 引擎 (Codex CLI) 與本機 LLM (Ollama) 透過 Model Context Protocol (MCP) 進行雙向串接的架構設計、實作步驟、邊界限制與可觀測性機制。

---

## 一、 系統架構與角色分工

在多代理人 (Multi-Agent) 開發架構中，不同模型依據其脈絡長度與推導特性承擔不同層級的職責：

| 代理人角色 | 核心引擎 | 職責定義 | 通訊協定 |
| :--- | :--- | :--- | :--- |
| **Antigravity (主控/長脈絡)** | Gemini 3.6 Flash | 架構規劃、長脈絡歷史檢索、多代理工作流分派與主介面呈現。 | MCP Client / JSON-RPC |
| **Codex (重構/二審)** | GPT-5.6 / Claude | 複雜代碼重構、單一檔案精確寫入、獨立二審審查。 | MCP Client & Server |
| **Ollama (本機隱私)** | Qwen3:8b (Q4_K_M) | 完全離線推導、敏感資料處理、零配額消耗作業。 | MCP Server & REST API |

---

## 二、 核心運作模式：二審 (Consult) 與委派 (Delegate)

代理人之間的互動分為兩種授權等級，以兼顧執行效率與專案檔案安全：

### 1. 唯讀二審模式 (Consult Mode)
* **目的**：在不修改實體檔案的前提下，取得第二代理人的獨立審查意見。
* **運作機制**：
  - 呼叫端傳送 `prompt` 與 `context`。
  - 受託端在**完全隔離的獨立暫存沙盒**（例如 `%TEMP%\agent-bridge-agy-...`）中啟動子行程。
  - 沙盒具備 `read-only` 限制，僅分析內容並以結構化 JSON 回傳報告。

### 2. 寫入委派模式 (Delegate Mode)
* **目的**：將指定模組或特定檔案的程式碼重構/編寫任務，分派給最合適的代理人執行。
* **運作機制**：
  - 呼叫端帶入專案目標目錄 (`cwd`)。
  - 受託端獲得 `workspace-write` 權限，在指定目錄下實體修改檔案、執行驗證。
  - 完成後回傳變更摘要、Diff 與驗證結果給主控端。

---

## 三、 進度可觀測性與使用者可控性 (Observability & Control)

為了防止背景跨代理人呼叫變成「黑盒子」或引發連線卡死，系統建立以下三層控管機制：

### 1. 主動狀態呈報 (No Silent Waiting)
- **條款規範**：代理人在發起跨模型 MCP 工具呼叫前，**必須第一時間輸出文字訊息告知使用者**（例如：「已發起對 Codex 的 MCP 呼叫，正於背景處理中...」）。
- **目的**：確保使用者隨時掌握系統狀態，避免無聲等待。

### 2. 10 分鐘 (600 秒) 雙向硬性超時防線
- **逾時控制**：在 MCP 伺服器 (`server.py`) 與全域規則 (`GEMINI.md` / `AGENTS.md`) 中，將工具呼叫超時上限統一鎖定為 600 秒。
- **異常處理**：若任務未能在 10 分鐘內完成，系統會中斷子行程，並主動向使用者回報已完成的步驟、當前進度與卡住的阻塞點。

### 3. 獨立檔案日誌 (File-Based Transparent Logging)
- **STDIO 管道保護**：MCP 的 JSON-RPC 傳輸絕不允許非 JSON 訊息（如 `print` 或控制條）寫入 `stdout`，否則會引發 `Transport closed` 崩潰。
- **透明日誌**：所有子行程的 PID、Exit Code、Raw Stdout 與 Raw Stderr 皆寫入獨立日誌檔 `agent-bridge-debug.log`，方便進行精確追蹤。

---

## 四、 實作與維運步驟

### 步驟 1：建立 Agent Bridge 與設定檔
1. 於 `agent-bridge` 中定義 MCP 工具（含 `health_check`、`consult_*`、`delegate_*`）。
2. 在 `server.py` 的核心包覆頂層 Exception Catch，防止子行程非預期拋出例外中斷 MCP 管道。

### 步驟 2：設定兩端 MCP 註冊
1. **Antigravity 側**：於 `mcp_config.json` 設定 `codex` (`codex mcp-server`) 與 `ollama`。
2. **Codex 側**：於 `config.toml` 設定 `agent_bridge` (`agent-bridge.exe`) 與 `ollama`。

### 步驟 3：重啟與兩階段驗證
1. **重啟 Client**：MCP 握手僅於 Client 啟動時發起，修改設定檔後須徹底關閉應用程式並重新開啟。
2. **健康檢查**：先呼叫不需 LLM 運算之 `health_check`，確認通訊管道建立。
3. **二審測試**：執行輕量 `consult_*` 測試，確認模型參數與 JSON 格式正確解析。

---

## 五、 系統限制與常態 QA

### 1. 為什麼 Codex / Antigravity 視窗上看不到對方的對話？
這是標準的 **Headless (無 UI) 背景模式**。跨代理人呼叫屬於背景 API 工具調用，不會彈出視窗或建立新分頁，避免干擾使用者正在進行的主視窗對話。

### 2. 跨代理人呼叫是否會額外計費？
- **Codex 呼叫**：直接借用本機已認證之 OAuth 憑證，扣抵既有 ChatGPT Pro / OpenAI 訂閱配額，無需額外 API Key。
- **Ollama 呼叫**：100% 於本機硬體運作，0 Token 費用。

### 3. 網頁版 (Web UI) 能否與本機桌面版連線？
網頁版運行於雲端瀏覽器沙盒中，預設無法存取本機 `localhost` 或本機子行程。若需連線，須透過 Cloud Tunnel 將本機端點暴露為公網網址。

### 4. 資源與效能限制
- 本機 Ollama 運作需佔用約 5~6 GB VRAM/RAM，推導速度取決於本機硬體性能。
- 跨代理人呼叫為單向單次 (One-Hop) 模式，嚴禁建立遞迴調用鏈 (Recursive Agent Chain)。
