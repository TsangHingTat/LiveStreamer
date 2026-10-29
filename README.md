# LiveStreamer Pro Studio 🎬

[![iOS](https://img.shields.io/badge/iOS-15.0%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-purple.svg)](https://developer.apple.com/xcode/swiftui/)
[![Tests](https://img.shields.io/badge/Tests-Passing-brightgreen.svg)]()

**LiveStreamer** 是一款專為 iPadOS 與 iOS 設計的廣播級即時導播切換器（Live Production Switcher）與多圖層場景編排系統。採用現代化 SwiftUI 與硬體加速管線打造，提供類似 ATEM Mini 與 OBS Studio 的雙監視器導播工作流。

---

## 🌟 核心特色 (Core Features)

- **雙 16:9 廣播級監視器（Dual Studio Monitors）**
  - **PREVIEW（預覽台 - 綠色 Tally）**：支援即時選取、拖曳排版與圖層微調。
  - **PROGRAM（直播主輸出 - 紅色 Tally）**：即時直播訊號，同步全螢幕鏡像至外接顯示器。
- **導播台轉場控制（Switcher Controls）**
  - **`CUT`**：硬切換，預覽場景瞬間進入 Program 主輸出。
  - **`AUTO`**：淡入淡出（Cross-Dissolve）平滑過渡。
  - **`BLACK`**：一鍵黑畫面（Fade to Black / FTB）。
- **多來源圖層引擎（Multi-Layer Scene Composition）**
  - **相機圖層 (Camera)**：整合 `AVCaptureSession`，支援前置 / 後置鏡頭一鍵切換與圓角排版。
  - **文字圖層 (Text)**：可自訂字型大小、顏色、粗體與旋轉角度，適用於即時字幕與即時跑馬燈。
  - **色塊圖層 (Color)**：自訂尺寸、色彩、圓角與不透明度，專用於 Lower Third 標題背景板。
  - **圖示圖層 (Image / Icon)**：支援 SF Symbols 向量圖形。
- **即時圖層屬性檢查器（Inspector）**
  - 具備 X / Y 座標位移、Scale 縮放（0.2x ~ 3.0x）、Rotation 旋轉（-180° ~ 180°）、Opacity 不透明度調整與「一鍵置中」輔助。
- **外部顯示螢幕與 AirPlay 無延遲投射**
  - 偵測 USB-C、HDMI 或 AirPlay 螢幕連接，透過獨立 `UIWindow` 原生渲染全螢幕 Program 畫面，無控制介面干擾。
- **高畫質 1080p 畫面快照（Snapshot to Photos）**
  - 透過 `ImageRenderer`（iOS 16+）將主輸出畫面以 1920×1080 無損保存至系統相簿。
- **安全狀態持久化（Persistence）**
  - 內建場景儲存機制，自動將多場景設定序列化為 JSON 儲存，重開 App 自動載入。

---

## 🚀 深度效能優化 (Architecture & Optimizations)

經過全面深度重構，本專案解決了先前版本的多個重大性能瓶頸：

| 項目 | 優化前 (Legacy) | 優化後 (Optimized v2.0) |
| :--- | :--- | :--- |
| **圖層渲染方式** | 90 FPS `Timer` 重複將視圖轉為 `UIImage` | **原生 SwiftUI 響應式圖形渲染（Zero Rasterization）** |
| **磁碟與記憶體 I/O** | 90 FPS 壓縮 JPEG 頻繁寫入/讀取 `UserDefaults` | **記憶體狀態共享（`StreamManager`），零磁碟 I/O** |
| **外接螢幕 / AirPlay** | 每秒 90 次從磁碟解碼圖片並顯示 | **原生 `UIHostingController` 雙視窗即時渲染（60/120Hz ProMotion）** |
| **資料架構** | 二維字串陣列 `[[String]]` 搭配百分比字串拼接 | **強型別 `LiveScene` 與 `SceneLayer` Codable 模型** |
| **系統時鐘** | 每次調用重新生成 `DateFormatter()` 與洩漏 Timer | **`TimelineView(.periodic)` 零記憶體洩漏與高效時鐘** |
| **崩潰防護** | 缺少 Camera / Photos 隱私權限宣告 | **補全 `Info.plist` 權限設定，防止實機崩潰** |

---

## 📁 檔案架構 (Project Structure)

```text
LiveStreamer/
├── LiveStreamerApp.swift       # 應用程式進入點、多視窗外接螢幕 (AirPlay/HDMI) 管理
├── ContentView.swift           # 主導播控制台介面（雙監視器、轉場按鈕、場景庫、來源庫、導播甲板）
├── SenceView.swift             # 核心模型、AVCapture 相機引擎、畫布渲染器與圖層檢查器 (Inspector)
├── ToolBarView.swift           # 頂部狀態列（LIVE/REC 狀態燈號、AirPlay 路由選取器、Studio 時鐘）
├── TimeView.swift              # 零洩漏錄製/直播時長計時器與 AVRoutePickerView 封裝
├── Info.plist                  # 系統相機與相簿隱私權限配置
└── Assets.xcassets/            # 應用程式圖示與色彩資源

LiveStreamerTests/
└── LiveStreamerTests.swift     # 單元測試（色彩序列化、場景編解碼、導播台切換邏輯測試）
```

---

## 🛠️ 開發環境與依賴 (Requirements)

- **macOS**：macOS 13.0 (Ventura) 或更高版本
- **Xcode**：Xcode 15.0+
- **目標裝置**：iPadOS 15.0+（建議使用 iPad Pro 橫向模式以獲得最佳導播體驗）或 iOS 15.0+
- **Swift 語言版本**：Swift 5.9+

---

## 🔨 建置與測試 (Build & Test)

使用命令列進行建置：

```bash
# 建置 App
xcodebuild -scheme LiveStreamer \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5) (16GB)' \
  build

# 執行單元測試
xcodebuild test -scheme LiveStreamer \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5) (16GB)' \
  -only-testing:LiveStreamerTests
```

---

## 📄 授權 (License)

Copyright (c) 2023-2026 HingTat Tsang. All rights reserved.

本軟體僅供個人非商業私人使用（Personal Non-Commercial Use Only），保留所有其他權利。未經作者書面許可，禁止用於任何商業、公開散布或參考引用用途。詳見 [LICENSE](LICENSE)。
