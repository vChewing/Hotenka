# Hotenka - DevPhases History Log

> 本文件作為 KnowledgeMemo4LLM.md 的附件單獨維護。
> 最後更新：2026-08-27（Phase 02 完結：zh2KX 康熙字典「一對多」語義誤轉的字詞消歧，鏡照自 vChewing-macOS Phase 152 第三波）
> AI Agent 得特別注意 KnowledgeMemo4LLM.md 所提到的「Response Pattern」。

---

## 附錄一、開發階段歷史

| 階段 | 主要內容 |
|------|----------|
| Phase 00 | 建立 Hotenka 的可用版本線：以 NCChineseConverter 的 Swift 化與 OpenCC 系字典資料為基礎，陸續完成首個可用版、公開 API、JSON 辭典支援、SQLite 載入，以及 statement pointer / memory leak 等修正，現有 git tag 可見 `v1.0.0`、`v1.1.0`、`v1.2.0`、`v1.3.0`。 |
| Phase 01 | 徹底重寫為 StringMap-only 架構。刪除 JSON / plist / SQLite / dictDir 載入路徑、SQLite3 依賴與 String C-level 擴充方法。轉換器改為 throwing init，只接受 StringMap 輸入，並在 convert/query 前做 canonical normalization；轉換熱路徑最終定稿為 direct StringMap lookup + longest-match scan。曾嘗試常駐 PrefixRewriter，但 memory profile 顯示它會吃回 StringMap 節省下來的 retained heap，因此已撤回。source-level attribution 已移除，但 README 文末保留一行 2022-2025 歷史斷代說明。 |
| Phase 02 | **zh2KX 康熙字典「一對多」語義誤轉的字詞消歧（鏡照自 vChewing-macOS Phase 152 第三波）**。勘查語料量級後（VanguardLexicon 詞庫含「才」詞多達數百條、罕見成語居多）採**移除式**設計：移除 zh2KX 三條破壞性單字對映（才→纔／參→蔘／核→覈），讓常見義項（才華／參與／核心）預設正確；補 39 條罕見義項詞條消歧（才·方才義→纔 13 條：剛才／方才／才剛／才一／才開始／才是／才會／才要／才不／才不會／才不是／才怪／才正要；參·人參義→蔘 16 條：人參／人參果／西洋參／高麗參／花旗參／黨參／丹參／紅參／白參／沙參／苦參／玄參／參茸／參須／參片／參湯；核·稽核義→覈 10 條：核實／核對／稽核／審核／核查／核銷／核減／核閱／核帳／核准）。漏網罕見詞維持原字（才／參／核皆為合法字、錯誤由語義誤傷降級為未轉古典字形、良性）。`zh2KX.txt` +39/−3、`convdict.stringmap` 以 `Hotenka.StringMap.serialize` 重生（四份鏡照逐字節一致：本倉 fixture、macOS Hotenka fixture、macOS MainAssembly4Darwin 生產、Legacy 生產）。探針實證：天才／才能／才華／參加／核心／原子核 全數維持原字；剛才→剛纔、人參→人蔘、核實→覈實 仍轉古典字形；吃→喫、口吃→口吃、為→爲 不受影響。`swift test` 8/8 ✅（含 `generatedFixturesAreDeterministic`，證明重生產物與測試生成一致）。詳見 `DevPlans/Reqs4LLM/Reqs_0151-0160.md` Phase 152 第三波。 |

---

## 附錄二、後續補記原則

1. 只有在 repo 範圍、公開 API、資料格式或驗證方式出現明顯里程碑時，才新增 phase 條目。
2. 若未來要把早期歷史補得更細，應以 git tag、release note、commit log 為依據，不要補寫無法證實的故事。
3. 若某次工作只是小修文件或測試，而不構成里程碑，更新對應 `Reqs4LLM` 分卷即可，不必強行新增 History phase。
