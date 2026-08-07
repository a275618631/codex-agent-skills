# 跨機器／跨帳號協作架構與風控拓展指南 (單機現狀與未來擴展藍圖)

> **文件狀態 (Metadata)**:  
> `status`: Proposal & Single-User PoC Architecture  
> `execution_allowed`: False (未經人工確認嚴禁自主執行)  
> `requires_human_approval`: True  

---

## 概述

本指南旨在說明跨主機、跨帳號多代理人 (Multi-Agent) 協作的技術實現路徑與安全控制框架。內容分為兩個層級：
1. **單人現狀與輕量優化**：針對單機環境的最小權限與安全邊界實作。
2. **未來可擴展藍圖**：參照 2026 最新 MCP 規格草案、A2A 協定、OWASP Agentic Top 10 與 OAuth 2.1 的生產級擴展架構。

---

## 第一部分：單人現狀架構與輕量優化參考

在單人單機開發環境中，核心原則是「在不增加無謂複雜度的前提下，確保極致的安全邊界與穩定性」。

### 1. 現有實作模式
* **權限隔離**：預設採用唯讀模式，敏感操作（寫入、刪除、部署、Git Push）需人工授權。
* **狀態分離**：禁止跨端傳遞私鑰、Token、Cookie、瀏覽器 Profile 或 `.env` 檔案；僅移植平台無關的 Skill、SOP 與 Prompt。
* **子行程與鎖保護**：使用本機 Cross-process PID 生存檢查與安全排他鎖，防止死鎖與競爭條件。
* **環境變數安全白名單**：實施嚴格的環境變數白名單過濾，子行程僅繼承必要的系統環境變數與 PATH，杜絕父行程之 `GITHUB_PERSONAL_ACCESS_TOKEN` 或其他敏感 Token 外洩。

### 2. 單人用輕量優化建議 (保持簡單，預留擴充)
* **主動狀態呈報**：在發起跨工具呼叫時，第一時間向控制台呈報發起狀態，減少無聲等待。
* **環境變數隔離**：執行子行程時強制注入 `NO_COLOR=1`、`TERM=dumb` 與 `PYTHONUNBUFFERED=1`，防止控制台雜訊污染 STDIO JSON-RPC 傳輸。
* **本機資源隔離**：確保本機工作目錄與系統家目錄受適當的作業系統權限保護。

---

## 第二部分：跨端協作技術路徑與未來可擴展藍圖

當系統需要從單機升級至跨機器、跨帳號或跨網域協作時，應採用以下標準化架構與風控規範。

### 1. 三類跨端協作實作模式 (Mode Distinction)

本架構精準區分三種不同層次的跨端實現技術，避免混淆：

```
+--------------------------------------------------------------------------+
|                       跨端協作三大技術實現路徑                              |
+------------------------------------+-------------------------------------+
| 1. Remote MCP                      | 2. 受控遠端執行 (Controlled Exec)    |
|    - 協定: 參照 MCP Streamable HTTP |    - 技術: SSH + JIT / Short-lived   |
|    - 版本: 2026-07-28 草案        |    - 用途: 受控維運與指令腳本執行    |
+------------------------------------+-------------------------------------+
| 3. 非同步任務中繼 (Async Task Relay)                                        |
|    - 技術: NATS / GitHub Issues / Slack Webhook                          |
|    - 協定藍圖: A2A v1 (Agent-to-Agent Protocol)                          |
+--------------------------------------------------------------------------+
```

1. **Remote MCP (開放協定層)**：
   - **通訊標準**：參照 `Transport: Streamable HTTP`（MCP Version 2026-07-28 草案），僅在必要時向下相容 Legacy SSE。
   - **應用場景**：提供跨主機的標準化遠端 Tool / Resource 呼叫介面。

2. **受控遠端執行 (Controlled Remote Execution)**：
   - **技術選擇**：採用 SSH 安全通道搭配限制型 Command。
   - **進階風控藍圖**：採短效 SSH Certificate / JIT 憑證、禁用 Agent Forwarding、實施 Forced Command 白名單與獨立低權限系統帳號，禁止直接提供互動式 Shell。

3. **非同步任務中繼與 A2A 規格藍圖 (Async Message Relay & A2A)**：
   - **中繼媒介**：採用 Message Broker (如 NATS) 或 GitHub Issues / Webhook 進行防火牆隔離下的非同步溝通。
   - **A2A v1 擴展藍圖**：將來擴展標準 Agent-to-Agent 協定時，需實作：
     - **Agent Card & 簽章**：能力介面宣告與 JWS / JSON Canonicalization 標準簽章。
     - **Task / Message 模型**：標準化 JSON-RPC / HTTP+JSON Binding 與 gRPC Binding。
     - **Webhook 驗證**：HTTPS、真實性簽名驗證、冪等處理 (Idempotency) 與限流。

---

### 2. 身份授權與資安風控擴展藍圖 (Security Roadmap)

#### 🅰️ 完整 OAuth 2.1 / OIDC 授權探索藍圖
未來從單人權限擴展至多租戶/跨帳號時，禁止單純傳遞硬編碼 Bearer Token，應建立符合 MCP 2026 規格草案的授權架構：
* **Protected Resource Metadata & OIDC Discovery**：自動探索授權伺服器端點。
* **Issuer & Audience 綁定**：防範 Token Passthrough 與冒用攻擊。
* **Scope 最小化與動態輪替**：每個代理人/租戶具備獨立 Workload Identity，Token 設定短過期時間與自動輪替。

#### 🅱️ OWASP Agentic Applications Top 10 全方位防護藍圖
針對多代理人系統常見的威脅模型，未來將實施以下護欄 (Guardrails)：
* **Prompt Injection / 間接指令注入**：將外部輸入與指令明確用 XML 標籤隔離、標記內容信任等級、實施 Data Taint Tracking 與操作前政策引擎。
* **Confused Deputy & Token Passthrough 護欄**：不允許代理人盲目轉發上遊權限，每層呼叫皆重新驗證 Scope。
* **SSRF 與 Tool Poisoning 防禦**：MCP 伺服器出口預設拒絕，限制可存取之 IP/網域白名單；工具註冊需經簽名驗證。
* **Log 去密化 (Secret Redaction)**：所有日誌落盤前強制過濾 Auth Header、Token、連線密碼與敏感資料。

---

### 3. 本系統統一 Task Envelope (Internal Contract)

跨主機系統未來將支援內部 Task Envelope 結構：

```json
{
  "schema_version": "1.0",
  "task_id": "uuid-v4",
  "parent_task_id": "uuid-v4-or-null",
  "trace_id": "uuid-v4",
  "idempotency_key": "string-hash",
  "requester_identity": "workload-id",
  "target_agent": "agent-name",
  "deadline": "RFC3339-timestamp",
  "max_tool_calls": 20,
  "approval_required": true
}
```

* **狀態機與重試機制**：支援 Exponential Backoff 重試、Dead-letter Queue (死信佇列) 與斷線重新接管。
* **冪等與 Checksum**：所有 Artifact 交付需附帶 Checksum 雜湊值驗證 integrity。

---

### 4. Cloud Tunnel 安全存取防線 (Cloud Safety Warning)

若需透過 Cloud Tunnel (如 Cloudflare Tunnel) 將本機或內部端點暴露為公網存取，**嚴禁裸露暴露**，必須實施以下安全防線：
1. **驗證與授權**：必須前置 OAuth 2.1 / OIDC 或 mTLS 身份驗證，禁止匿名入口。
2. **網路隔離**：嚴禁 Tunnel 直接存取整體 LAN，僅限存取特定沙盒容器端點。
3. **安全防護**：啟用 WAF、防 Replay 機制與 Rate Limiting，並配置短期端點自動撤銷與完整 Session Audit Log。
