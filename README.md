# Hotenka Engine 步天歌引擎

- Gitee: [Swift](https://gitee.com/vChewing/Hotenka)
- GitHub: [Swift](https://github.com/vChewing/Hotenka)

步天歌引擎是一套簡繁轉換模組。簡繁轉換資料使用 OpenCC 的轉換資料（Apache License 2.0）且有做了一些修改。

Hotenka Engine is a module for converting between Simplified Chinese and Traditional Chinese. This module uses the translation data from OpenCC (Apache License 2.0).

## 使用說明

```swift
import Hotenka

let converter = try HotenkaChineseConverter(stringMapPath: "path/to/convdict.stringmap")
let converted = converter.convert("为中华崛起而读书", to: .zhHantTW)
print(converted) // 為中華崛起而讀書
```

`StringMap` 是 Hotenka 的緊湊文字格式：檔案本身是 UTF-8 純文字，Git 會把它當成一般 text file。載入時會先正規化 CRLF。`convert` 會先做 canonical normalization，接著以 longest-match scan 搭配 `maximumKeyLength` 上界直接查詢 `StringMap`；這保留了低 heap 特性，不再為了 trie 索引額外常駐大型記憶體結構。

測試會自動重建 `Tests/HotenkaTestDictData/convdict.stringmap`。

## 著作權 (Credits)

- (c) 2026 and onwards The vChewing Project (MIT-NTL License).
  - Programmer: Shiki Suen
- Translation data from OpenCC (Apache License 2.0).

> The previous 2022-2025 version was a Swift rewrite of Nick Chen's Obj-C library "NCChineseConverter" (MIT License). The current implementation (since April 2026) is a complete rewrite with no backward compatibility.
