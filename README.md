# Minidoracat Dismantle Any Car MP

用噴燈把任何車拆成金屬材料，完好的車也可以。單人與多人伺服器都能用，多人由伺服器重新檢查。

Project Zomboid Build 42 MOD。

## 功能

- **任何車都能拆**：完好的車與拖車的右鍵選單多一個「拆解車輛」，需求和原版拆殘骸相同（焊接面罩、噴燈 10 單位）。燒毀與撞毀的車照原版。
- **多人伺服器可用**：拆車與給材料在伺服器執行，伺服器重新檢查車還在、玩家在車旁邊、車上沒有人、拖車上沒有動物。
- **車內物品提醒**：車內還有物品時先跳確認框；確認後物品和車一起消失。
- **產出倍率**：沙盒選項「拆車產出倍率」（0–10，預設 1.0）。
- **拆車紀錄**：伺服器每拆一台車在 `Logs/*_MinidoracatDismantle.txt` 記一行。
- **介面語言**：繁體中文、简体中文、English、日本語、한국어、Русский、Español、Português、Türkçe、Français、Polski、Deutsch。

## 相容性

- 不需要其他 MOD。沿用原版的拆除動作，所以保護這個動作的車輛保護 MOD（例如 Minidoracat 車輛管理）照常運作。
- 請不要和其他修改拆車動作的 MOD 同時啟用。

## 安裝

- Steam Workshop：（首次上傳後補上連結）
- 手動安裝：把 `MOD/MinidoracatDismantleFor42/Contents/mods/MinidoracatDismantleFor42` 複製到 `%USERPROFILE%\Zomboid\mods\` 並將資料夾改名為 `MinidoracatDismantleFor42`

## 開發

- `link_workshop.bat`：手動同步、唯讀狀態與歸檔卸載；MOD 以實體副本放入 `Zomboid\Workshop\` 與 `Zomboid\mods\`，不使用目錄連結
- `PZ_Test.bat`：暗色點選視窗，啟動前增量同步目前 MOD 與家族依賴；首次預設 no-Steam，之後記住各專案的選擇。需要換檔但遊戲仍在執行時拒絕同步與新啟動，不停止既有遊戲；完整驗證與資料邊界見 `../pz-family-docs/tools.md`
- `Publish_Workshop.bat`：發布到 Steam Workshop（需 Steam 用戶端已登入；可選擇只更新內容／封面／簡介；首發仍走遊戲內上傳器）

## 版本

版本號格式：`{PZ 版本}-{mod 版本}`（例 `42.22.2-0.1.0`），詳見 [CHANGELOG.md](CHANGELOG.md)。

## 作者

Minidoracat — [Discord](https://discord.gg/Gur2V67) | [Twitch](https://www.twitch.tv/minidoracat)
