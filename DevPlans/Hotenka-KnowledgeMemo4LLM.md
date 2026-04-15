# Hotenka - 格物致知專用文件

> 本文檔供 AI Agent 在每次幹活前迅速了解專案全貌。
> 最後更新：2026-08-27（Phase 02 完結：zh2KX 康熙字典「一對多」語義誤轉的字詞消歧——移除破壞性單字對映＋39 條罕見義項詞條；鏡照自 vChewing-macOS Phase 152 第三波）
> AI Agent 得特別注意本文所提到的「Response Pattern」。

---

## 一、專案概述

**Hotenka** 是一個專注於**簡繁中文轉換**的 Swift Package。轉換資料採 OpenCC 系資料並做在地化調整。README 文末保留一行歷史說明：2022-2025 版本曾是 NCChineseConverter 的 Swift rewrite；當前 2026 版實作則已重寫且不考慮向後相容。

- **套件型態**：單一 SwiftPM library product `Hotenka`
- **Package manifest**：`// swift-tools-version: 6.2`
- **外部 Swift 套件依賴**：無
- **系統模組依賴**：`Foundation`
- **授權**：MIT-NTL License（見根目錄 `LICENSE`）

> 這個 repo 目前的實際範圍，是一個字典驅動的中文轉換器與其測試資料，不應寫成 Trie / 語言模型 / 組字器 / 多模組 IME pipeline。

---

## 二、專案架構

### 2.1 目錄結構

```
[REPO_ROOT]/
├── Package.swift
├── README.md
├── LICENSE
├── makefile
├── .gitattributes
├── Sources/
│   └── Hotenka/
│       ├── HotenkaChineseConverter.swift
│       └── HotenkaStringMap.swift
├── Tests/
│   ├── HotenkaTests/
│   │   ├── HotenkaTestSupport.swift
│   │   └── HotenkaTests_StringMap.swift
│   └── HotenkaTestDictData/
│       ├── zh2TW.txt
│       ├── zh2HK.txt
│       ├── zh2SG.txt
│       ├── zh2JP.txt
│       ├── zh2KX.txt
│       ├── zh2CN.txt
│       └── convdict.stringmap
└── DevPlans/
    ├── Hotenka-KnowledgeMemo4LLM.md
    ├── Hotenka-DevReqsHistory.md
    └── Reqs4LLM/
```

### 2.2 技術架構

```
Hotenka (單一 library target)
├── DictType
├── Hotenka.StringMap
└── HotenkaChineseConverter
    ├── init(stringMapPath:) throws
    ├── init(stringMap:)
    ├── query(dict:key:)
    └── convert(_:to:)
        └── longest-match scan over StringMap
```

測試端的資料流如下：

```
Tests/HotenkaTestDictData/*.txt
    -> loadSourceDictionary() 載入為 [String: [String: String]]
    -> StringMap.serialize(from:) 產生 convdict.stringmap
    -> HotenkaChineseConverter(stringMapPath:) 載入並轉換
    -> verifySampleConversion() 跑回歸驗證
    -> testGeneratedFixturesAreDeterministic() 驗證 StringMap byte-for-byte 一致
```

---

## 三、核心資料模型

| 型別 / 成員 | 所在位置 | 用途 |
|------|------|------|
| `DictType` | `HotenkaChineseConverter.swift` | 六種辭典方向列舉：`zh2TW` / `zh2HK` / `zh2SG` / `zh2JP` / `zh2KX` / `zh2CN` |
| `DictType.rawKeyString` | 同上 | 將列舉值映射到實際檔名與字典 key |
| `HotenkaChineseConverter` | 同上 | 主轉換器，以 StringMap 為唯一輸入格式 |
| `maximumKeyLengths: [Int]` | 同上（private let） | 六個字典方向的最大鍵長表，用來縮小 longest-match scan 視窗 |
| `Hotenka.StringMap` | `HotenkaStringMap.swift` | 緊湊文字格式；UTF-8 header + ASCII hex index table + 原始文字 data block |

---

## 四、核心組件詳解

### 4.1 DictType — 字典方向列舉

`DictType` 是整個轉換器的入口索引。每個 case 對應一組實際字典檔名：

- `zhHantTW` -> `zh2TW`
- `zhHantHK` -> `zh2HK`
- `zhHansSG` -> `zh2SG`
- `zhHansJP` -> `zh2JP`
- `zhHantKX` -> `zh2KX`
- `zhHansCN` -> `zh2CN`

### 4.2 HotenkaChineseConverter

轉換器目前只有一條載入路徑：**StringMap**。

- `init(stringMapPath:) throws`：載入 StringMap 檔案並建立最大鍵長表
- `init(stringMap:)`：直接從已載入的 StringMap 建立轉換器
- `convert(_:to:)`：先做 canonical normalization，再以 longest-match scan 直接查詢 StringMap
- `query(dict:key:)`：先做 canonical normalization，再做 exact query

不再有 JSON / plist / SQLite / dictDir 路徑。init 為 throwing，不會靜默吞掉錯誤。

### 4.3 轉換核心 — Canonical-Normalized Longest-Match Scan

`convert(_:to:)` 的實作：

1. 對輸入先做 canonical normalization（`precomposedStringWithCanonicalMapping`）
2. 依字典方向讀取對應的 `maximumKeyLength`
3. 在每個起點從最長候選一路往下縮短
4. 直接呼叫 `StringMap.query(dict:key:)` 做 exact query
5. 命中時輸出替換值，未命中時原樣輸出一個字元

這個版本放棄了常駐 trie。原因不是功能性，而是實測 memory profile 證明 trie 會把 StringMap 省下的 retained heap 吃回去，因此最終版本改回直接查詢 StringMap，只保留一張極小的最大鍵長表。

### 4.4 StringMap — Text-Based 單一連續 Data

`Hotenka.StringMap` 的格式設計：

- 檔頭保存 magic (`HTSMAPTXT`) / version / dict count 與各字典區段 offset
- 每個辭典方向有固定長度 descriptor，記錄 entry count、maximum key length、index start、data start、data end
- index table 以固定寬度 ASCII hex line 保存每筆記錄在 data block 內的起始位移
- data block 直接保存排序後的 `key<TAB>value<LF>` UTF-8 文字
- 載入時會先把 `CRLF` 正規化成 `LF`
- 仍保留 binary search 的 exact query
- 轉換器只額外保留一張最大鍵長表，不再常駐 trie / prefix index

序列化天然 deterministic，適合作為穩定 fixture 與 production format。

---

## 五、已實作功能清單

- 以 Swift 實作的簡繁中文轉換器
- 以 OpenCC 系資料為基底的六組字典方向
- StringMap 緊湊文字格式的載入與序列化
- canonical-normalized longest-match scan
- StringMap CRLF 輸入相容
- StringMap deterministic fixture 生成與 byte-for-byte 驗證
- StringMap UTF-8 text-based 產物驗證
- sample phrase 回歸測試
- composed/decomposed Unicode regression test
- retained-memory profile test

---

## 附錄一、開發階段歷史

因該章節會逐漸累積，故挪至 `[REPO_ROOT]/DevPlans/Hotenka-DevReqsHistory.md` 單獨管理。

---

## 附錄二、已知問題與注意事項

### A2.1 當前已知問題 / 現況約束

1. `DevPlans/Reqs4LLM/Reqs_0011-0020.md` 目前仍為空白骨架；後續 phase 尚未正式起草。
2. `swift test` 會重建 `Tests/HotenkaTestDictData/convdict.stringmap`；這是衍生產物，不是手工維護來源。
3. `makefile` 目前只定義 `lint` 與 `format`。
4. `Package.swift` 目前沒有 `platforms` 宣告。

### A2.2 開發注意事項

1. 先看 `Package.swift`、`README.md`、`Sources/Hotenka/HotenkaChineseConverter.swift`，再決定文件怎麼寫。
2. 若改動 `HotenkaChineseConverter` 的行為，至少要跑 `swift test`。
3. `Tests/HotenkaTests` 是由一個 `XCTestCase` 類別加一個 test support enum 組成。
4. 這個 repo 目前沒有 Trie、LM、候選窗、組字、Braille、拼音 parser 等模組。

---

## 九、關鍵檔案速查

| 檔案路徑 | 說明 |
|----------|------|
| `Package.swift` | 單一 `Hotenka` library product 的 SwiftPM 定義 |
| `README.md` | 專案用途與基本使用說明 |
| `makefile` | 目前僅有 `lint` / `format` 兩個目標 |
| `Sources/Hotenka/HotenkaChineseConverter.swift` | 主轉換器、DictType 列舉、canonical-normalized longest-match scan |
| `Sources/Hotenka/HotenkaStringMap.swift` | StringMap 純文字格式、header/index/data layout、詞條迭代 |
| `Tests/HotenkaTests/HotenkaTestSupport.swift` | fixture builder、txt 字典載入器、sample conversion 驗證 |
| `Tests/HotenkaTests/HotenkaTests_StringMap.swift` | StringMap fixture 生成、載入、CRLF 相容、deterministic 驗證 |
| `Tests/HotenkaTestDictData/` | 六組原始 txt 字典與衍生 StringMap fixture |

---

## AI Agent 反應模式（Response Pattern）

> 本節供 AI Agent 參考，當用戶提出新的 Phase 開發任務時，應遵循以下標準流程。

### 10.1 工作流程（Workflow）

當用戶提出新的 Phase 需求時，按以下順序執行：

```
┌─────────────────────────────────────────────────────────────────┐
│  Step 1: 讀取相關檔案                                            │
│  - 讀取用戶指定的 Phase 描述         │
│  - 讀取需要修改的原始碼檔案                                       │
│  - 確認現有實作與新需求的關聯                                     │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  Step 2: 程式碼實作                                              │
│  - 根據需求實作功能                                              │
│  - 遵循專案現有程式碼風格（層級結構）         │
│  - 複用既有組件和工具函數                                        │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  Step 3: 編譯驗證                                                │
│  - swift build                     │
│  - 確保無錯誤、無警告                                           │
│  - 如有錯誤立即修復                                              │
│  - 然後先 make lint，接著立刻 make format，然後只看這兩步疊加後留下的實際結果與可編譯狀態。           │
│  - 再次重試編譯                           │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  Step 4: 文件同步（並行執行）                                     │
│  ├─ DevPlans/Reqs4LLM 當中對應的 Phase 檔案: 添加 Phase 規格與實作備忘錄 │
│  ├─ Hotenka-KnowledgeMemo4LLM.md: 更新開發階段歷史表格           │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  Step 5: 彙總報告                                                │
│  - 列出所有變更的檔案                                            │
│  - 說明核心實作邏輯                                              │
│  - 確認編譯狀態                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 10.2 文件更新規則

| 檔案 | 更新時機 | 內容格式 |
|------|---------|----------|
| **Hotenka-KnowledgeMemo4LLM.md** | 每個 Phase 必須 | 在「開發階段歷史」表格中添加一行 `\| Phase XX \| 簡短描述 \|` |
| **UserGuide (4語言)** | 影響使用者操作時 | 在對應章節添加功能說明（鍵盤熱鍵、滑鼠操作等） |

### 10.3 程式碼實作原則

1. **最小變更原則**：只做必要的修改，不改動無關程式碼
2. **風格一致性**：
   - 使用 `// Phase XX:` 註解標記新代碼
   - 遵循現有命名慣例（如 `handleXxx`, `onXxx`）
   - 保持縮排和空行風格
3. **平台相容性**：
   - (今後會按需求補充)
4. **狀態管理**：
   - (今後會按需求補充)

### 10.4 常見任務類型

| 任務類型 | 典型檔案 | 注意事項 |
|----------|----------|----------|

### 10.5 回報格式範本

```markdown
## 變更總結

### 程式碼變更

**檔案名稱.swift**:
- 變更項目 1
- 變更項目 2

### 文件更新

| 檔案 | 更新內容 | 注意事項 |
|------|---------|---------|
| DevPlans/Reqs4LLM/Reqs_????.md | 新增 Phase XX 規格與實作備忘錄 | 注意優先編輯以數字為 filename stem suffix 的分卷檔案，每個分卷最多 10 個 Phase，超出了就請新增分卷檔案。如果完成的任務剛好是當前分卷的最後一個任務（第十個任務）的話，請以新的分卷命名創建空白 markdown 檔案（除非該檔案已存在）。 |
| DevPlans/Hotenka-KnowledgeMemo4LLM.md | 根據專案實際情況更新內容（如適用） | 參考既往記錄的文書風格。 |
| DevPlans/Hotenka-DevReqsHistory.md | 新增 Phase XX 到開發階段歷史 | 參考既往記錄的文書風格。 |

### 編譯狀態

✅ 編譯通過 / ❌ 有錯誤（說明）
```

### 10.6 工作細節附註

- 交差前注意與 L10n 有關的內容是否全部補齊。
- 如果要使用 tmp 目錄的話，請使用 `[REPO_ROOT]/tmp` 目錄、而非 `/tmp/`。使用 `/tmp/` 這種 out-of-workspace 的路徑會迫使事主每次都得手動設定存取權限，非常麻煩。
- 如果事主丟給您 Xcode Instruments Profile 檔案的話，可能會是二進位檔案，請先嘗試用 `xctrace export` 解讀成 XML 再分析。
- 每次交差之前運行 `make lint; make format`。如果事主明確要你對某些工作單獨 commit 的話，每次 commit 之前也請運行 `make lint; make format`。事主謀求的格式整理結果乃 **這兩道命令按順序達成的修改效果之總和**，且這兩條命令必須得先 lint 後 format 且不得顛倒順序。但注意在運行之後也請 build 一次，因為這兩道命令對 `count == 0` 的範式會頑固地轉換成 `.isEmpty` 而不會檢查相關 type 是否有 `isEmpty` 這個 read-only property。發現這種情況的話，可以用 `.count * 1 == 0` 取代之。commit 的 title 格式是 `ModuleName // WhatHasBeenFixed`、且在 commit 的 description 的末尾單獨一行寫明 `(Phase XXX - Task YYY)`。Commit Titles 始終以 ASCII Period `.` 結尾，除非是疑問句時才使用 `?` 結尾。
- 給 ChatGPT、Codex、Raptor 的特殊指令：Do not intentionally stop with tasks incompleted to ask me whether you do the next step I already told you. Just do it. I have backups, hence no worry. // Claude、Kimi、GLM、QwenCoder 從來不用問這些問題，就能把這些事情全部做好。唯獨 ChatGPT、Codex、Raptor 不這樣，就很奇怪很令人窩火。

---

> ⚠️ **注意**: 本文檔需要定期更新以反映最新程式碼狀態。如有發現過期內容，請及時修正。
