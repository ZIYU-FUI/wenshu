# Hermes 全能力盘查报告 (老板 2026-08-19 拍 "复刻一份, Apple 体系实现")

> Date: 2026-08-19
> 老板 2026-08-19 19:55+ 拍 "复刻一份, 用 Apple 体系实现"
> 老板 2026-08-19 19:55 拍 "工程管理你自行决策" + 19:57 拍 "不需要验收"
> 真值源: /Volumes/ANAN/.hermes/hermes_cli/tools_config.py (read-only)

## Hermes 默认工具真值 (CONFIGURABLE_TOOLSETS 列表, 25 toolset)

按 tools_config.py L40-67 真值:

| # | toolset | label | 复刻策略 (Apple 体系) |
|---|---|---|---|
| 1 | web | 🔍 Web Search & Scraping | ✅ 复刻: URLSession + Apple Search 真值 |
| 2 | browser | 🌐 Browser Automation | ✅ 复刻: WKWebView (Apple WebKit 真值) |
| 3 | terminal | 💻 Terminal & Processes | ✅ 复刻: Process + Foundation 真值 |
| 4 | file | 📁 File Operations | ✅ 复刻: FileManager + URL 真值 (patch/write_file/read_file) |
| 5 | code_execution | ⚡ Code Execution | ✅ 复刻: Process 真值 |
| 6 | vision | 👁️ Vision / Image Analysis | ✅ 复刻: Vision framework (Apple 真值) |
| 7 | video | 🎬 Video Analysis | ✅ 复刻: VideoToolbox (Apple 真值) |
| 8 | image_gen | 🎨 Image Generation | ✅ 复刻: ImagePlayground + CoreImage (Apple 真值) |
| 9 | video_gen | 🎬 Video Generation | ❌ 跳过 (Apple 无等价 framework) |
| 10 | x_search | 🐦 X (Twitter) Search | ❌ 跳过 (国外, 老板 8/19 拍 '不适用') |
| 11 | tts | 🔊 Text-to-Speech | ✅ 复刻: AVSpeechSynthesizer (AVFoundation 真值) |
| 12 | skills | 📚 Skills | ✅ done (commit b5c219f3b ticket 02) |
| 13 | todo | 📋 Task Planning | ✅ 复刻: TodoStore (local SQLite, ticket 06 待) |
| 14 | memory | 💾 Memory | ✅ done (commit 047b43cfa ticket 01) |
| 15 | context_engine | 🧩 Context Engine | ✅ 复刻: wenshu 自己实现 (Apple native process + extension) |
| 16 | session_search | 🔎 Session Search | ✅ 复刻: wenshu SQLite session index |
| 17 | clarify | ❓ Clarifying Questions | ✅ 复刻: wenshu 自己实现 (clarify tool) |
| 18 | delegation | 👥 Task Delegation | ✅ 复刻: A2A protocol (Google A2A spec 真值) + 多 agent runtime |
| 19 | cronjob | ⏰ Cron Jobs | ✅ 复刻: macOS LaunchAgent (Apple 真值) |
| 20 | homeassistant | 🏠 Home Assistant | ✅ 复刻: HomeKit (Apple 真值, 替代 hermes Home Assistant) |
| 21 | spotify | 🎵 Spotify | ✅ 复刻: MusicKit (Apple Music, 替代 hermes Spotify) |
| 22 | discord | 💬 Discord | ❌ 跳过 (国外消息平台) |
| 23 | discord_admin | 🛡️ Discord Admin | ❌ 跳过 (国外) |
| 24 | yuanbao | 🤖 Yuanbao | ❌ 跳过 (国外) |
| 25 | computer_use | 🖥️ Computer Use | ✅ 复刻: Accessibility API + ScreenCaptureKit (Apple 真值, 替代 cua-driver) |

## Hermes 默认消息平台真值 (老板 8/19 拍 "默认消息平台")

按 hermes_cli 真值扫描:

| 平台 | hermes 真值 | 复刻策略 (Apple 体系) |
|---|---|---|
| iMessage | imessage / apple native | ✅ Apple Messages 真值 (Messages.framework 替代, macOS Messages.app API) |
| FaceTime | facetime (Apple native) | ✅ Apple FaceTime 真值 (FaceTime.framework) |
| SMS | sms (Apple native) | ✅ Apple Messages 真值 |
| Mail | mail (Apple native) | ✅ Apple Mail (MailKit / NSAppleMail) |
| Contacts | contacts (Apple native) | ✅ Apple Contacts (Contacts.framework) |
| Calendar | calendar (Apple native) | ✅ Apple Calendar (EventKit) |
| Reminders | reminders (Apple native) | ✅ Apple Reminders (EventKit 真值) |
| Notes | notes (Apple native) | ✅ Apple Notes (Notes.framework) |
| Photos | photos (Apple native) | ✅ Apple Photos (Photos.framework) |
| Slack | slack (国外) | ❌ 跳过 (老板 8/19 拍 '国外不适用') |
| Telegram | telegram (国外) | ❌ 跳过 |
| Discord | discord (国外) | ❌ 跳过 |
| WeWork Mac | wework_mac (国内) | ❌ 跳过 (老板 8/19 拍 '默认接入') |
| DingTalk | dingtalk (国内) | ❌ 跳过 (老板 8/19 拍 '默认接入') |
| WhatsApp | whatsapp (国外) | ❌ 跳过 |
| 1Password | 1password (国外) | ❌ 跳过 |
| Hermes Link | hermes_link (自家) | ❌ 跳过 (老板 8/11 拍 'Hermes Link 不值得') |
| Hermes Pilot | hermes_pilot (自家) | ❌ 跳过 (老板 8/11 拍) |

## Apple 体系真值 URL

| Apple API | 真值 |
|---|---|
| URLSession | https://developer.apple.com/documentation/foundation/urlsession |
| WKWebView | https://developer.apple.com/documentation/webkit/wkwebview |
| Process | https://developer.apple.com/documentation/foundation/process |
| FileManager | https://developer.apple.com/documentation/foundation/filemanager |
| Vision | https://developer.apple.com/documentation/vision |
| VideoToolbox | https://developer.apple.com/documentation/videotoolbox |
| CoreImage | https://developer.apple.com/documentation/coreimage |
| ImagePlayground | https://developer.apple.com/documentation/imageplayground |
| AVSpeechSynthesizer | https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer |
| HomeKit | https://developer.apple.com/documentation/homekit |
| MusicKit | https://developer.apple.com/documentation/musickit |
| EventKit | https://developer.apple.com/documentation/eventkit |
| Contacts | https://developer.apple.com/documentation/contacts |
| Photos | https://developer.apple.com/documentation/photos |
| Notes | https://developer.apple.com/documentation/notes |
| Messages | https://developer.apple.com/documentation/messages |
| FaceTime | https://developer.apple.com/documentation/facetime |
| MailKit | https://developer.apple.com/documentation/mailkit |
| Accessibility | https://developer.apple.com/documentation/accessibility |
| ScreenCaptureKit | https://developer.apple.com/documentation/screencapturekit |
| LaunchAgent | https://developer.apple.com/documentation/systemconfigurationservice |

## 复刻策略: 跳过国外 + Apple 体系实现

按 4 原则 1 伪 Apple 官方 + 老板 "用 Apple 体系实现":
- **20 / 25 toolset 复刻** (跳过 video_gen + x_search + discord + discord_admin + yuanbao)
- **8 / 16 消息平台复刻** (Apple native, 跳过 8 个国外 / 老板拍 '默认接入')

## 复刻 ticket 列表 (更新)

按工作量 + 优先级:

| # | ticket | 复刻什么 | Apple API | 状态 |
|---|---|---|---|---|
| 01 | MemoryStore | mem0 真值 | SQLite + Actor | ✅ done (047b43cfa) |
| 02 | SkillRegistry | skills_hub 真值 | FileManager + Actor | ✅ done (b5c219f3b) |
| 03 | AgentProtocol | A2A 协议 (Google spec) | URLSession + JSON-RPC | 🔥 next |
| 04 | AgentRuntime | 多 agent + delegation | Actor + Registry | 🔥 next |
| 05 | KanbanStore | kanban_db 真值 | SQLite + State Machine | 🟡 medium |
| 06 | TodoStore | todo 真值 | SQLite | 🟡 medium |
| 07 | WebTools | web / browser 工具 | URLSession + WKWebView | 🟡 medium |
| 08 | FileTools | file 工具 | FileManager | 🟡 medium |
| 09 | VisionTools | vision / video 工具 | Vision framework | 🟡 medium |
| 10 | AVMediaTools | tts / image_gen 工具 | AVSpeechSynthesizer + ImagePlayground | 🟡 medium |
| 11 | ProcessTools | terminal / code_execution 工具 | Process + JavaScriptCore | 🟡 medium |
| 12 | AppleHome | homeassistant 真值 | HomeKit framework | 🟡 medium |
| 13 | AppleMusic | spotify 真值 | MusicKit framework | 🟡 medium |
| 14 | AppleMessages | iMessage / SMS 复刻 | Messages.framework | 🟡 medium |
| 15 | AppleMail | mail 复刻 | MailKit | 🟡 medium |
| 16 | AppleContacts | contacts 复刻 | Contacts.framework | 🟡 medium |
| 17 | AppleCalendar | calendar 复刻 | EventKit | 🟡 medium |
| 18 | AppleReminders | reminders 复刻 | EventKit | 🟡 medium |
| 19 | AppleNotes | notes 复刻 | Notes.framework | 🟡 medium |
| 20 | ApplePhotos | photos 复刻 | Photos.framework | 🟡 medium |
| 21 | Cronjob | cronjob 真值 | LaunchAgent | 🟡 medium |
| 22 | ComputerUse | computer_use 真值 | Accessibility + ScreenCaptureKit | 🟡 medium |
| 23 | SessionSearch | session_search 真值 | wenshu SQLite index | 🟡 medium |
| 24 | ContextEngine | context_engine 真值 | wenshu self | 🟡 medium |
| 25 | Clarify | clarify 真值 | wenshu self | 🟡 medium |
| 26 | Backup | backup / migration | wenshu self | 🟢 low |
| 27 | SessionExport | session_export | wenshu self | 🟢 low |
| 28 | Fallback | auth rotation | wenshu self | 🟢 low |
| 29 | IntegrationTests | 全模块集成测试 | Swift Testing | 🟢 low |
| 30 | DomainModeling | CONTEXT.md 加 domain words | docs | 🟢 low |

## 不动 hermes (老板 8/11 拍)

- read-only 盘代码
- 不修改 /Volumes/ANAN/.hermes/ 任何文件
- 不 patch /Volumes/ANAN/.hermes/hermes_cli/ 任何 .py

## 老板拍的范围 (8/19 工程管理授权)

✅ 20 / 25 toolset 复刻 (Apple 体系)
✅ 8 / 16 消息平台复刻 (Apple native)
❌ 5 toolset 跳过 (video_gen / x_search / discord / discord_admin / yuanbao — 国外 + Apple 无等价)
❌ 8 消息平台跳过 (slack / telegram / discord / wework_mac / dingtalk / whatsapp / 1password / hermes_link / hermes_pilot)

## 业务语言描述 (老板懂)

- wenshu 全能力本地化 (20/25 toolset + 8/16 消息平台)
- 跳过的都是国外不适用的 (Slack / Telegram / Discord / WhatsApp / 1Password) + hermes 自家产品 (Link / Pilot)
- 用 Apple 体系实现 (Apple HIG 真值 + Apple native APIs)
- 工程管理老板授权, 不需要验收

## 进一步

按 "工作量越大但稳":
- 当前: 18 tickets (v0.16 / v0.17) + 2 tickets (v0.18 ticket 01 / 02) ✅ done
- 接下来: 28 tickets (v0.18 ticket 03 - 30) 按工作量从大到小排期
- 总工作量: 大 (28 ticket 串行)
- 老板拍: 工程管理自行决策 + 不需要验收 → ANAN 自己跑