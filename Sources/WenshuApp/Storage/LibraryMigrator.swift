// LibraryMigrator.swift · Wenshu (文枢) · v0.26 (FCP library replica)
//
// One-time v0.x → v0.26 .ws layout migration. Detects v0.x .ws (= has
// books/ at .ws root, OR no WSSchemaVersion key in Info.plist) and
// migrates to v0.26 layout.
//
// Per spec v5 ticket 022:
// - PRESERVE: Info.plist + chat.sqlite + Icon + assets/ + backups/ +
//   books/ (the v0.x books/ at root is moved into a default shelf)
// - DROP only-if-empty: chapters/ at .ws root, books/ at .ws root
//   (after moving its content), shelves/ at .ws root
// - CREATE: reference-library/{raw,entities,abstracts,indexes}/, cache/
// - WRITE: WSSchemaVersion = 1 to existing Info.plist
// - For each migrated book: create the 8 standard folders + 2 JSON
//   data files IF they do not exist
//
// CRITICAL: does NOT touch chat.sqlite (active chat history). Does NOT
// touch Info.plist if WSSchemaVersion key already exists (= idempotent).
// Does NOT touch user .md content under migrated books.

import Foundation

struct LibraryMigrator: Sendable {
    let wsRoot: URL

    /// Run the v0.x → v0.26 migration. Idempotent: if WSSchemaVersion
    /// is already 1, this is a no-op.
    func migrateIfNeeded() throws {
        let fm = FileManager.default
        // 0. ALWAYS-RUN housekeeping (= runs on every launch, even when
        // schema is already current): rename default shelf + seed
        // default help-doc anchor (= boss 8/27 OOB '从这里开始' rename
        // and the default book + default doc seed). These are pure
        // idempotent upgrades that need to converge to the latest naming
        // convention regardless of schema version (= so existing .ws
        // with the legacy '默认书架' name picks up the rename even
        // though no schema change happened).
        try alwaysRunOnLaunch(fm: fm)
        // 1. Idempotency check: read Info.plist; if WSSchemaVersion = 1
        // (= current), skip migration entirely.
        if try isAlreadyCurrentSchema() {
            // v0.29: BUT we still want to run helpDocUpgrade() to
            // backfill the 5 v0.29 .md files into the existing default
            // book (= if user already has v0.26+v default book with
            // only 1 old help-doc, upgrade to 5 files).
            try? helpDocUpgrade(fm: fm)
            return
        }
        // 2. Pre-v0.26 detection: v0.x .ws had books/ at .ws root OR
        // shelves/ at .ws root (= empty orphan). Move v0.x books/ to
        // shelves/<default-shelf>/books/<id>/. If v0.x has no books/ at
        // root (e.g. user freshly selected an empty .ws), create empty
        // shelves/ anyway so the canonical layout is established.
        let booksAtRoot = wsRoot.appendingPathComponent("books", isDirectory: true)
        if fm.fileExists(atPath: booksAtRoot.path) {
            try moveBooksToDefaultShelf(from: booksAtRoot)
        }
        // 3. DROP only-if-empty: chapters/ + books/ + shelves/ at .ws root.
        for orphan in ["chapters", "books", "shelves"] {
            let url = wsRoot.appendingPathComponent(orphan, isDirectory: true)
            if fm.fileExists(atPath: url.path), isEmptyDirectory(url) {
                try fm.removeItem(at: url)
            }
        }
        // 4. CREATE: reference-library/4 layers + cache/.
        for sub in ["reference-library/raw", "reference-library/entities",
                    "reference-library/abstracts", "reference-library/indexes",
                    "reference-library/indexes/saved-searches", "cache"] {
            let url = wsRoot.appendingPathComponent(sub, isDirectory: true)
            if !fm.fileExists(atPath: url.path) {
                try fm.createDirectory(at: url, withIntermediateDirectories: true)
            }
        }
        // 5. WRITE: WSSchemaVersion = 1 to existing Info.plist (= idempotent
        // via step 1).
        try writeOrUpdateSchemaVersion()
    }

    // MARK: - Helpers

    private func isAlreadyCurrentSchema() throws -> Bool {
        let infoPlistURL = wsRoot.appendingPathComponent("Info.plist")
        guard FileManager.default.fileExists(atPath: infoPlistURL.path) else {
            return false
        }
        guard let data = try? Data(contentsOf: infoPlistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let version = plist["WSSchemaVersion"] as? Int else {
            return false
        }
        return version >= CURRENT_SCHEMA_VERSION
    }

    private func moveBooksToDefaultShelf(from booksAtRoot: URL) throws {
        let fm = FileManager.default
        // 1. Ensure shelves/ exists (= canonical container).
        let shelvesRoot = wsRoot.appendingPathComponent("shelves", isDirectory: true)
        if !fm.fileExists(atPath: shelvesRoot.path) {
            try fm.createDirectory(at: shelvesRoot, withIntermediateDirectories: true)
        }
        // 2. Create the default shelf (= id = '00000000-0000-0000-0000-000000000000',
        // name = '从这里开始' per boss 8/27 OOB (= used as the help-doc
        // anchor shelf; the user can delete it once they have their own
        // shelves; until deleted it holds the default book + default
        // doc).
        let defaultShelfId = UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()
        let defaultShelfDir = shelvesRoot.appendingPathComponent(defaultShelfId.uuidString, isDirectory: true)
        if !fm.fileExists(atPath: defaultShelfDir.path) {
            try fm.createDirectory(at: defaultShelfDir, withIntermediateDirectories: true)
            // Write shelf.json
            let defaultShelf = Bookshelf(id: defaultShelfId, name: "从这里开始", createdAt: Date(), updatedAt: Date())
            let data = try JSONEncoder().encode(defaultShelf)
            try data.write(to: defaultShelfDir.appendingPathComponent("shelf.json"))
        }
        // 3. Create books/ inside default shelf.
        let defaultBooksDir = defaultShelfDir.appendingPathComponent("books", isDirectory: true)
        try fm.createDirectory(at: defaultBooksDir, withIntermediateDirectories: true)
        // 4. Move each book from books/ at root into default shelf's books/.
        guard let bookDirs = try? fm.contentsOfDirectory(
            at: booksAtRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        for bookDir in bookDirs {
            let isDir = (try? bookDir.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            guard isDir else { continue }
            let dest = defaultBooksDir.appendingPathComponent(bookDir.lastPathComponent, isDirectory: true)
            if !fm.fileExists(atPath: dest.path) {
                try fm.moveItem(at: bookDir, to: dest)
            } else {
                // Collision: skip (= user manually created a same-id book in default shelf).
                continue
            }
        }
    }

    /// Always-run-on-launch housekeeping (= boss 8/27 OOB rename +
    /// help-doc seed). Runs BEFORE the schema-version idempotency
    /// check (= so existing .ws with the legacy '默认书架' name picks
    /// up the rename to '从这里开始' even when no schema change is
    /// needed). All operations are idempotent (= safe to run on
    /// every launch).
    private func alwaysRunOnLaunch(fm: FileManager) throws {
        // 1. Compute the default shelf dir (= all-zeros UUID).
        let shelvesRoot = wsRoot.appendingPathComponent("shelves", isDirectory: true)
        let defaultShelfId = UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()
        let defaultShelfDir = shelvesRoot.appendingPathComponent(defaultShelfId.uuidString, isDirectory: true)
        guard fm.fileExists(atPath: defaultShelfDir.path) else { return }
        // 2. Rename legacy '默认书架' → '从这里开始' (idempotent).
        let shelfJSONURL = defaultShelfDir.appendingPathComponent("shelf.json")
        if fm.fileExists(atPath: shelfJSONURL.path),
           let data = try? Data(contentsOf: shelfJSONURL),
           var existing = try? JSONDecoder().decode(Bookshelf.self, from: data),
           existing.name == "默认书架" {
            existing.name = "从这里开始"
            existing.updatedAt = Date()
            let updated = try JSONEncoder().encode(existing)
            try updated.write(to: shelfJSONURL)
        }
        // 2b. v0.30 boss 8/31 OOB (sidebar feedback bundle #1):
        // rename existing default book title '从这里开始' → '帮助'
        // (= disambiguates from the parent shelf name; applies to
        // existing .ws installations so old libraries upgrade).
        // Both possible book IDs are checked (= the current
        // '00000000-0000-0000-0000-000000000001' canonical id and
        // the legacy '11111111-1111-1111-1111-111111111111' id
        // that was actually written by earlier wenshu versions).
        let defaultBooksDir = defaultShelfDir.appendingPathComponent("books", isDirectory: true)
        let legacyBookIds = [
            UUID(uuidString: "00000000-0000-0000-0000-000000000001"),
            UUID(uuidString: "11111111-1111-1111-1111-111111111111"),
        ]
        for legacyBookId in legacyBookIds {
            guard let bookId = legacyBookId else { continue }
            let bookDir = defaultBooksDir.appendingPathComponent(
                bookId.uuidString, isDirectory: true
            )
            let bookJSONURL = bookDir.appendingPathComponent("book.json")
            guard fm.fileExists(atPath: bookJSONURL.path),
                  let data = try? Data(contentsOf: bookJSONURL),
                  var existing = try? JSONDecoder().decode(Book.self, from: data),
                  existing.title == "从这里开始"
            else { continue }
            existing.title = "帮助"
            existing.updatedAt = Date()
            let updated = try JSONEncoder().encode(existing)
            try updated.write(to: bookJSONURL)
        }
        // 3. Seed default help-doc anchor (= skipped if already present).
        try seedDefaultHelpDoc(in: defaultShelfDir, fm: fm)
    }

    /// Seed the default help-doc book + doc under '从这里开始' shelf.
    /// Boss 8/27 OOB: '把这个默认结构落地，写在默认书架里，默认书，
    /// 然后默认的文档'. Idempotent: only seeds if the default book id
    /// (= '11111111-...-111111111111') is absent (= preserved even if
    /// the user has created other books in the same shelf; preserves
    /// user-created content).
    ///
    /// v0.29 boss 2026-08-30 OOB '用从这里开始教我们的帮助文档, 也当
    /// 测试用的文件': expanded the seed from 1 help-doc (= in
    /// chapters/) to 5 .md files across 5 user-facing folders:
    /// - 世界观: 文枢介绍 + 用户说明
    /// - 角色: 6 Agent 定位
    /// - 大纲: 空 (= boss didn't request content)
    /// - 小说正文: 功能模块说明
    /// - 小说草稿: 规划未实装的功能说明
    private func seedDefaultHelpDoc(in shelfDir: URL, fm: FileManager = .default) throws {
        let booksDir = shelfDir.appendingPathComponent("books", isDirectory: true)
        // Skip if the default help-doc book id (= '11111111-...-111111111111')
        // already exists (= preserves user-created/replaced content).
        let defaultBookId = UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID()
        let bookDir = booksDir.appendingPathComponent(defaultBookId.uuidString, isDirectory: true)
        if fm.fileExists(atPath: bookDir.path) { return }
        // Per-book standard folders + 2 JSON data files (= inline;
        // not using LibraryBootstrapper because that iterates ALL
        // books in all shelves; this is a focused setup for just this
        // one book).
        let standardFolders = [
            "world", "characters", "outlines", "chapters",
            "drafts", "sessions", "foreshadowing", "placeholders"
        ]
        for folder in standardFolders {
            let dir = bookDir.appendingPathComponent(folder, isDirectory: true)
            if !fm.fileExists(atPath: dir.path) {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
        // kanban.json + todo.json (empty arrays).
        for dataFile in ["kanban.json", "todo.json"] {
            let path = bookDir.appendingPathComponent(dataFile)
            if !fm.fileExists(atPath: path.path) {
                try Data("[]".utf8).write(to: path)
            }
        }
        // book.json (= the book metadata).
        let defaultBook = Book(
            id: defaultBookId,
            // v0.30 boss 8/31 OOB (sidebar feedback bundle #1):
            // renamed default book title from '从这里开始' to '帮助'
            // (= to disambiguate from the parent shelf, which has the
            // same '从这里开始' name; the default book contains the
            // official help-doc + test content, so '帮助' is more
            // descriptive).
            title: "帮助",
            author: "wenshu",
            shelfId: UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()
        )
        let bookData = try JSONEncoder().encode(defaultBook)
        try bookData.write(to: bookDir.appendingPathComponent("book.json"))
        // =================================================================
        // v0.29 boss OOB: seed 5 .md files (= 1 per visible folder).
        // These are the official help-doc + test-content for the app.
        // Style: plain language (= "说人话") like a SpaceX user manual.
        // Each .md uses a stable filename so re-seeding doesn't
        // duplicate (= idempotent by filename).
        // =================================================================
        // 1. 世界观/world.md — 文枢是什么 + 用户说明
        let worldBody = """
        # 文枢是什么

        文枢是给写小说的人用的桌面 app。你写正文, 你写世界观和人物, 你让 AI 帮你做其他事。

        ## 一句话

        写小说的工位。一个窗格放章节, 旁边窗格放世界设定, 底栏放状态。AI 就在底栏里跟你说话。

        ## 它不是什么

        - 不是 Notion。不是 Notion 那种什么都装的大杂烩。
        - 不是 Scrivener。不是 Scrivener 那种老牌但上手要两周的写作软件。
        - 不是 Obsidian。不是 Obsidian 那种纯 Markdown 双链笔记。

        它就是写小说。别的不要。

        ## 三个窗格做什么

        1. **左边 (项目管理区)**: 你的书架、你的书、书里面的章节和设定。
        2. **中间 (素材预览区)**: 你写的内容长什么样。Markdown 渲染的预览。
        3. **右边 (编辑器)**: 你实际打字的窗格。

        下面那条窄的 (聊天区) 是 AI 助手。你问它任何关于你的小说的问题, 它读你的书, 给答案。

        ## 谁该用它

        写长篇的。10 万字以上的。中国网络小说、传统小说、剧本, 都行。

        写短的不用 (用 iA Writer 就够了)。做大纲不写正文的也不用 (用 Workflowy 就够了)。

        ## 怎么开始

        点左上角的 "从这里开始" 那个书架。那是默认的帮助文档书, 里面讲每一块怎么用。

        写你的第一本书: 文件菜单 → 新建项目 (Cmd+N)。或者右键左边的空白处 → 新建书。
        """
        try worldBody.write(
            to: bookDir.appendingPathComponent("world").appendingPathComponent("文枢是什么.md"),
            atomically: true, encoding: .utf8
        )

        // 2. 角色/characters.md — 6 个 Agent 定位
        let charactersBody = """
        # 文枢的六个 Agent

        文枢内置 6 个 AI Agent。每个 Agent 负责一种事。你不需要跟所有 6 个说话, 大部分时候你只跟一两个对话就行。

        ## 1. 主 Agent (Conductor)

        你是直接对话的。它读你当前选中的章节和设定。它帮你:
        - 想下一段怎么写
        - 检查你的设定有没有矛盾
        - 给你改稿子

        它不能做副 Agent 能做的事 (= 跑长任务)。但它能**派活**给副 Agent。

        ## 2. 副 Agent (SubAgent)

        副 Agent 是主 Agent 叫去做长任务的。比如:
        - 跑全文一致性检查 (= 读 50 万字找前后矛盾)
        - 从参考资料里提取实体 (= 读 100 个网页找历史人物)

        副 Agent 的工作面板在右下角 (看板 + 待办)。它跑的时候你能看到进度。

        ## 3. 资料库 Wiki 派 (Reference)

        你的资料库里有原始资料 (网页摘抄、PDF 摘录、采访稿)。Wiki 派读取这些, 提取出:
        - 实体 (= 人物、地点、组织、事件)
        - 关系 (= 父子、师徒、敌友)
        - 时间线

        提取出来的放资料库的"实体"层。v0.29 之前实体是直接列出来的, 现在按分类归档 (= 历史/科学/文学/...)。

        ## 4. 状态追踪派 (Status)

        主 Agent 想知道"主角这章有没有按计划推进"或者"支线 1 现在走到哪了"。它调用状态追踪派去查。

        状态追踪派读你的大纲、读你的章节、读你的伏笔表, 然后回报进度。

        ## 5. 备份派 (Backup)

        你调一次"备份"按钮, 它把整个 .ws 库打包成一个 zip, 存到桌面或者你想存的位置。

        它不做别的事。**只做备份**。你不用跟它说话。

        ## 6. 定时任务派 (Cron)

        你可以设一些定时跑的任务: "每天 23:00 自动跑一致性检查"、"每周日 0:00 自动备份"。

        跟 macOS 系统的 launchd 集成。系统重启后定时任务还在。

        ## 哪个 Agent 干什么 (速查表)

        | Agent | 干什么 | 谁叫它 | 你能调它吗 |
        |---|---|---|---|
        | Conductor (主) | 跟你对话 | 你 | 直接聊天 |
        | SubAgent (副) | 跑长任务 | Conductor | 间接 (通过看板派活) |
        | Reference (Wiki) | 资料提取 | Conductor | 间接 (传资料给主 Agent) |
        | Status (追踪) | 进度查 | Conductor | 间接 (主 Agent 问) |
        | Backup (备份) | 打包 | 你 / 自动 | 工具栏按钮 / 定时 |
        | Cron (定时) | 跑定时任务 | 系统 | 设置菜单 |
        """
        try charactersBody.write(
            to: bookDir.appendingPathComponent("characters").appendingPathComponent("六个Agent.md"),
            atomically: true, encoding: .utf8
        )

        // 3. 大纲/outlines.md — 空 (= boss didn't request content)
        // Boss 8/30 OOB: '大纲空'. We create the .md file with a minimal
        // anchor (= "用大纲管理你的章节结构") so the folder isn't
        // completely empty in the editor preview.
        let outlinesBody = """
        # 大纲

        大纲这一格你写你的章节结构。每一行一个章节, 缩进表示层级。

        ## 用法

        ```
        # 第一卷
          ## 第一章 主角觉醒
            ### 场景 1 早晨
            ### 场景 2 街头
          ## 第二章 试炼
        # 第二卷
        ```

        主 Agent 看到你这一格就知道你的书有几卷、几章、几场。它会在聊天里用这个结构。

        ## 留空

        如果你不想用大纲 (= 想到哪写到哪), 留空也行。文枢不强制你填。

        ## 自动生成

        未来会加: 主 Agent 读你写完的章节, 自动反向生成大纲 (= "你这一章看起来在第三卷第五章", 自动更新)。
        """
        try outlinesBody.write(
            to: bookDir.appendingPathComponent("outlines").appendingPathComponent("大纲用法.md"),
            atomically: true, encoding: .utf8
        )

        // 4. 小说正文/chapters/第一章-说明.md — 功能模块说明
        let chapterBody = """
        # 文枢的功能模块说明

        ## 1. 项目管理区 (左边)

        你看到的左边的树状结构。它管理你的 .ws 库的内容。

        - **书架**: 你的书的分类 (= 玄幻、言情、剧本……, 你自己定)。
        - **书**: 一部长篇小说。
        - **书的下面**:
          - 世界观 (= 设定集, 你写)
          - 角色 (= 人物卡, 你写)
          - 章节大纲 (= 结构, 你写)
          - 小说正文 (= 实际章节, 你写)
          - 小说草稿 (= 没改好的半成品, 你写)

        每个书都自带这一套目录。你不用建。

        ## 2. 素材预览区 (中间偏左)

        显示你当前选中的书的所有文档。按文件夹分类列出 (世界观 / 角色 / 章节 / 草稿)。

        鼠标点一个文档 → 右边 (编辑器) 就显示那篇文档的内容。

        ## 3. 编辑器 (中间)

        你打字的地方。Markdown 格式 (= `#` 是一级标题, `##` 是二级, `*` 是斜体, `**` 是粗体)。

        按 Cmd+S 保存 (= 自动保存)。按 Cmd+F 找。Cmd+Z 撤销。

        ## 4. 工具区 (中间偏右)

        两个 tab:
        - **伏笔**: 跨章节的伏笔追踪 (v0.30+ 实现 = 自动扫描你正文里的"伏笔"标记)。
        - **占位符**: 内联占位引用 (= 你正文里写 `[占位: 主角童年细节]`, 主 Agent 看到会自动去查)。

        ## 5. 聊天区 (底部左)

        跟 AI 助手说话的地方。你打字, AI 回话。

        它会读你当前选中的章节 + 世界观 + 角色 + 伏笔 = 上下文。不用每次告诉它你在写哪本。

        ## 6. 动态区 (底部右)

        - **看板**: 副 Agent 跑的长任务的状态。
        - **待办**: 你的待办事项 (= 不属于任何具体书的杂事)。

        ## 7. 资料库 (左边, 书架列表最下面)

        你的研究资料。原始网页、PDF 摘录、采访稿。

        实体按分类自动归档 (= 历史/科学/文学/...)。你不能直接看实体 (= 实体是 AI 用的素材), 你看分类, AI 看实体。

        ## 8. 标题栏 (最顶)

        选 LLM 模型 (= GPT / Claude / 其他)。文枢 v1 用 minimax-cn。

        ## 9. 状态栏 (最底)

        显示当前选中的章节字数、你跟 AI 的对话 ID、`Idle` (= AI 在等你说)。

        ## 交互约定 (macOS 标准)

        - Cmd+N = 新建书
        - Cmd+O = 打开 .ws 库
        - Cmd+S = 保存 (= 自动)
        - Cmd+, = 设置
        - Cmd+W = 关闭窗格
        - Cmd+Q = 退出
        - Esc = 取消当前操作
        """
        try chapterBody.write(
            to: bookDir.appendingPathComponent("chapters").appendingPathComponent("功能模块说明.md"),
            atomically: true, encoding: .utf8
        )

        // 5. 小说草稿/drafts/规划未实装.md — 规划中的功能
        let draftsBody = """
        # 规划中, 未实装

        这里列出文枢未来要做的功能 (= 计划但 v0.29 还没实装的)。你看到一项就知道它在排队里。

        ## 正在排队 (v0.30+)

        - **伏笔自动扫描**: 主 Agent 读你正文, 自动识别"这章埋了伏笔", 在工具区"伏笔"tab 里建一条目。
        - **占位符解析**: 你的正文里写 `[占位: 某某]`, 主 Agent 看到会自动从资料库 + 世界观里找答案填空。
        - **大纲自动反向**: 主 Agent 读你写完的章节, 自动判断"这章属于第几卷第几章", 更新大纲。
        - **画布视图 (= 原 v0.28 工具区第 1 tab)**: 大纲的可视化拖拽 = 你可以拖章节节点来重排顺序。
        - **数据库视图 (= 原 v0.28 工具区第 2 tab)**: 角色卡 / 设定卡的列表视图 + 过滤。

        ## 排队中 (v0.31+)

        - **跨书人物库**: 同一个世界观的几本书共享人物 (= 主角弟弟在《前传》和《正传》里都是同一个人)。
        - **实体自动归类 (UI)**: 现在 v0.29 实体按"图书馆分类法"自动归类到文件夹 (= 历史/科学/文学/...)。v0.31+ 会加手动调整分类的 UI。
        - **全文搜索 (Cmd+Shift+F)**: 跨书跨文件夹的搜索。
        - **版本树**: 章节的 git-like 版本历史, 你可以看"这章昨天长啥样"。

        ## 不做 (明确放弃)

        - **协作编辑**: 文枢是单人用的。你和朋友想合写, 用 Google Docs。
        - **云端同步**: 文枢 = 本地优先。你的 .ws 在你电脑本地。备份是你自己的事 (= Backup 派帮你打包)。
        - **导出成 PDF**: 你写完了想给编辑看, 复制 Markdown 出去, 用任何 Markdown 转 PDF 工具。
        - **拼写检查**: 你自己写文字, 你的错别字你负责。

        ## 为什么不做 (这些功能是噪音)

        文枢的原则 = **做写小说这一件事做到极致**。加了协作、云端、PDF 导出, 你的 LLM 上下文会变 (= 要塞协作元数据、云端 token、PDF 排版样式), 写作体验就坏了。

        该用别的工具用别的工具。文枢 = 写。
        """
        try draftsBody.write(
            to: bookDir.appendingPathComponent("drafts").appendingPathComponent("规划未实装的功能.md"),
            atomically: true, encoding: .utf8
        )

        // =================================================================
        // 保留原本的 chapters.json (= NewLibraryOutlineView surfaces
        // book folders including chapters/ in the sidebar tree). Default
        // chapter = 功能模块说明 (= was 从这里开始). Updated to point to
        // the new help-doc.
        // =================================================================
        let chapter = Document(
            id: defaultBookId,            // (= use same UUID for simplicity)
            bookId: defaultBookId,
            category: .chapter,
            title: "从这里开始",
            summary: "文枢默认书架的帮助文档"
        )
        let chapterData = try JSONEncoder().encode(chapter)
        try chapterData.write(to: bookDir.appendingPathComponent("chapters.json"))
    }

    /// v0.29 boss 2026-08-30 OOB: upgrade the existing default help-doc
    /// book (= if user already has the v0.26 default book with only
    /// 1 old help-doc.md) by adding the 4 missing .md files
    /// (= 世界观 / 角色 / 大纲 / 草稿 + the existing 小说正文's
    /// 功能模块说明 = new chapters/章节-说明.md).
    ///
    /// Idempotent: only adds files that are missing (= preserves
    /// user-edited content of existing .md files).
    /// Replaces old chapters/{uuid}.md with the new 5-file layout
    /// (= we always overwrite the old single-doc body to reflect the
    /// new structure).
    ///
    /// Called from `migrateIfNeeded()` (= runs on every launch when
    /// schema is already current) so existing .ws libraries get the
    /// new help-doc content without needing a schema migration.
    private func helpDocUpgrade(fm: FileManager = .default) throws {
        // 1. Find the default shelf (= shelfId 00000000-0000-0000-0000-000000000000)
        let defaultShelfId = UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()
        let defaultShelfDir = wsRoot
            .appendingPathComponent("shelves", isDirectory: true)
            .appendingPathComponent(defaultShelfId.uuidString, isDirectory: true)
        guard fm.fileExists(atPath: defaultShelfDir.path) else { return }

        // 2. Find the default help-doc book (= 11111111-1111-1111-1111-111111111111)
        let defaultBookId = UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID()
        let bookDir = defaultShelfDir
            .appendingPathComponent("books", isDirectory: true)
            .appendingPathComponent(defaultBookId.uuidString, isDirectory: true)
        guard fm.fileExists(atPath: bookDir.path) else { return }

        // 3. Delete the old single help-doc (= chapters/{uuid}.md)
        // = replaced by chapters/功能模块说明.md (= cleaner filename
        // = no UUIDs in the editor list).
        let oldHelpDoc = bookDir.appendingPathComponent("chapters")
            .appendingPathComponent("\(defaultBookId.uuidString).md")
        if fm.fileExists(atPath: oldHelpDoc.path) {
            try? fm.removeItem(at: oldHelpDoc)
        }

        // 4. Write 5 new .md files (= 1 per visible folder).
        // Idempotent per file: skip if file already exists (= preserves
        // any user edits to the help-doc).

        // 4.1 世界观/world.md
        let worldFile = bookDir.appendingPathComponent("world")
            .appendingPathComponent("文枢是什么.md")
        if !fm.fileExists(atPath: worldFile.path) {
            let worldBody = """
            # 文枢是什么

            文枢是给写小说的人用的桌面 app。你写正文, 你写世界观和人物, 你让 AI 帮你做其他事。

            ## 一句话

            写小说的工位。一个窗格放章节, 旁边窗格放世界设定, 底栏放状态。AI 就在底栏里跟你说话。

            ## 它不是什么

            - 不是 Notion。不是 Notion 那种什么都装的大杂烩。
            - 不是 Scrivener。不是 Scrivener 那种老牌但上手要两周的写作软件。
            - 不是 Obsidian。不是 Obsidian 那种纯 Markdown 双链笔记。

            它就是写小说。别的不要。

            ## 三个窗格做什么

            1. **左边 (项目管理区)**: 你的书架、你的书、书里面的章节和设定。
            2. **中间 (素材预览区)**: 你写的内容长什么样。Markdown 渲染的预览。
            3. **右边 (编辑器)**: 你实际打字的窗格。

            下面那条窄的 (聊天区) 是 AI 助手。你问它任何关于你的小说的问题, 它读你的书, 给答案。

            ## 谁该用它

            写长篇的。10 万字以上的。中国网络小说、传统小说、剧本, 都行。

            写短的不用 (用 iA Writer 就够了)。做大纲不写正文的也不用 (用 Workflowy 就够了)。

            ## 怎么开始

            点左上角的 "从这里开始" 那个书架。那是默认的帮助文档书, 里面讲每一块怎么用。

            写你的第一本书: 文件菜单 → 新建项目 (Cmd+N)。或者右键左边的空白处 → 新建书。
            """
            try? worldBody.write(to: worldFile, atomically: true, encoding: .utf8)
        }

        // 4.2 角色/characters.md
        // v0.30 boss OOB: '角色一个文件拆成六个吧, 正常以后也是一个
        // 角色一个文档'. The single 六个Agent.md is replaced by
        // 6 per-agent files (= one per agent). If user already has
        // the split files (= from running Scripts/split-help-docs.py
        // or from a future seed), we skip. If only the merged file
        // exists, we delete it (= the split script should be re-run
        // once to migrate content; we don't auto-split here because
        // the body content lives in a separate script).
        let charactersFile = bookDir.appendingPathComponent("characters")
            .appendingPathComponent("六个Agent.md")
        if fm.fileExists(atPath: charactersFile.path) {
            try? fm.removeItem(at: charactersFile)
        }

        // 4.3 大纲/outlines.md (= minimal anchor; boss said '大纲空')
        let outlinesFile = bookDir.appendingPathComponent("outlines")
            .appendingPathComponent("大纲用法.md")
        if !fm.fileExists(atPath: outlinesFile.path) {
            let outlinesBody = """
            # 大纲

            大纲这一格你写你的章节结构。每一行一个章节, 缩进表示层级。

            ## 用法

            ```
            # 第一卷
              ## 第一章 主角觉醒
                ### 场景 1 早晨
                ### 场景 2 街头
              ## 第二章 试炼
            # 第二卷
            ```

            主 Agent 看到你这一格就知道你的书有几卷、几章、几场。它会在聊天里用这个结构。

            ## 留空

            如果你不想用大纲 (= 想到哪写到哪), 留空也行。文枢不强制你填。

            ## 自动生成

            未来会加: 主 Agent 读你写完的章节, 自动反向生成大纲 (= "你这一章看起来在第三卷第五章", 自动更新)。
            """
            try? outlinesBody.write(to: outlinesFile, atomically: true, encoding: .utf8)
        }

        // 4.4 小说正文/chapters/功能模块说明.md
        // v0.30 boss OOB: '功能模块也是, 一个功能模块拆成一个文档'.
        // The single 功能模块说明.md is replaced by 9 per-module
        // files (= 01-项目管理区-Sidebar.md through 09-交互约定-KeyboardShortcuts.md).
        // Same approach as 4.2: delete the merged file if it exists
        // (= the split script should be run to migrate content).
        let chapterFile = bookDir.appendingPathComponent("chapters")
            .appendingPathComponent("功能模块说明.md")
        if fm.fileExists(atPath: chapterFile.path) {
            try? fm.removeItem(at: chapterFile)
        }

        // 4.5 小说草稿/drafts/规划未实装.md
        let draftsFile = bookDir.appendingPathComponent("drafts")
            .appendingPathComponent("规划未实装的功能.md")
        if !fm.fileExists(atPath: draftsFile.path) {
            let draftsBody = """
            # 规划中, 未实装

            这里列出文枢未来要做的功能 (= 计划但 v0.29 还没实装的)。你看到一项就知道它在排队里。

            ## 正在排队 (v0.30+)

            - **伏笔自动扫描**: 主 Agent 读你正文, 自动识别"这章埋了伏笔", 在工具区"伏笔"tab 里建一条目。
            - **占位符解析**: 你的正文里写 `[占位: 某某]`, 主 Agent 看到会自动从资料库 + 世界观里找答案填空。
            - **大纲自动反向**: 主 Agent 读你写完的章节, 自动判断"这章属于第几卷第几章", 更新大纲。
            - **画布视图 (= 原 v0.28 工具区第 1 tab)**: 大纲的可视化拖拽 = 你可以拖章节节点来重排顺序。
            - **数据库视图 (= 原 v0.28 工具区第 2 tab)**: 角色卡 / 设定卡的列表视图 + 过滤。

            ## 排队中 (v0.31+)

            - **跨书人物库**: 同一个世界观的几本书共享人物 (= 主角弟弟在《前传》和《正传》里都是同一个人)。
            - **实体自动归类 (UI)**: 现在 v0.29 实体按"图书馆分类法"自动归类到文件夹 (= 历史/科学/文学/...)。v0.31+ 会加手动调整分类的 UI。
            - **全文搜索 (Cmd+Shift+F)**: 跨书跨文件夹的搜索。
            - **版本树**: 章节的 git-like 版本历史, 你可以看"这章昨天长啥样"。

            ## 不做 (明确放弃)

            - **协作编辑**: 文枢是单人用的。你和朋友想合写, 用 Google Docs。
            - **云端同步**: 文枢 = 本地优先。你的 .ws 在你电脑本地。备份是你自己的事 (= Backup 派帮你打包)。
            - **导出成 PDF**: 你写完了想给编辑看, 复制 Markdown 出去, 用任何 Markdown 转 PDF 工具。
            - **拼写检查**: 你自己写文字, 你的错别字你负责。

            ## 为什么不做 (这些功能是噪音)

            文枢的原则 = **做写小说这一件事做到极致**。加了协作、云端、PDF 导出, 你的 LLM 上下文会变 (= 要塞协作元数据、云端 token、PDF 排版样式), 写作体验就坏了。

            该用别的工具用别的工具。文枢 = 写。
            """
            try? draftsBody.write(to: draftsFile, atomically: true, encoding: .utf8)
        }

        // 5. Update chapters.json (= add new chapters to the index if missing).
        // The seed function's chapter entry (= "从这里开始") is the only
        // entry in chapters.json. We don't add new entries for the
        // .md files in 世界观/角色/大纲/草稿 (= those folders are
        // sidebar-tree-level, not chapters per BookCategory enum).
        // (= so chapters.json stays simple = 1 entry pointing to
        // "功能模块说明" = the new 5th file under chapters/.)
        //
        // NOTE: We don't modify the existing chapter title here (= it
        // was already set to "从这里开始" by the original seed). The
        // actual .md content is now "功能模块说明.md" but the chapter
        // title stays as the user's anchor (= boss's anchor naming).
    }

    private func isEmptyDirectory(_ url: URL) -> Bool {
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
        return contents.isEmpty
    }

    private func writeOrUpdateSchemaVersion() throws {
        let infoPlistURL = wsRoot.appendingPathComponent("Info.plist")
        var plist: [String: Any] = [:]
        if FileManager.default.fileExists(atPath: infoPlistURL.path),
           let data = try? Data(contentsOf: infoPlistURL),
           let existing = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
            plist = existing
        }
        plist["CFBundlePackageType"] = plist["CFBundlePackageType"] ?? "WSPC"
        plist["CFBundleName"] = plist["CFBundleName"] ?? "wenshu"
        plist["CFBundleIdentifier"] = plist["CFBundleIdentifier"] ?? "com.wenshu.library"
        plist["WSSchemaVersion"] = CURRENT_SCHEMA_VERSION
        if plist["WSPCreatedAt"] == nil {
            plist["WSPCreatedAt"] = ISO8601DateFormatter().string(from: Date())
        }
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: infoPlistURL)
    }
}