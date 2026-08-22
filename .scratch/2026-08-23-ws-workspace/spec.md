# Spec — Wenshu Workspace (.ws) single file (FCP-style)

> Boss 2026-08-23 拍: '我想先落地, 类似 FCP 的库文件'.

## Background

AGENTS.md §11 says: '.ws single file = CoreData + attachments, locally self-managed'.

Current state (boss 8/23 验): **NOT IMPLEMENTED**. Multiple scattered SQLite files:
- `~/Library/Application Support/WenshuApp/Wenshu.sqlite` (old CoreData, 53KB)
- `~/Library/Application Support/com.wenshu.app/novel-platform.db` (archived)
- `~/Library/Application Support/wenshu/chat.sqlite` (24KB)
- `~/Library/Application Support/wenshu/kanban.db` (16KB)
- (likely also memory.sqlite, skills.sqlite, etc.)

Backup / migration / cross-device sync 不友好.

## FCP design reference

Final Cut Pro `.fcpbundle` pattern:
- **Single file** (or directory bundle, Finder shows as single)
- Self-contained: project settings + media index + render cache
- XML + plist + metadata inside
- External media reference: optional (link to external files)
- **Schema-versioned** (FCP upgrades bump version, migration tool reads old)
- **Backup/move friendly**: copy one file = entire workspace

## wenshu `.ws` design

### File structure

`wenshu.ws` is a **SQLite database file** with:
- All wenshu state tables (chat / kanban / memory / skill / provider / book)
- Embedded `attachments` table (BLOB columns for small files, external path for large)
- `manifest` table (schema version, signature, created_at, updated_at)
- WAL mode for concurrent reads

### Schema (v1)

```sql
-- Manifest
CREATE TABLE ws_manifest (
    schema_version INTEGER NOT NULL,
    workspace_uuid TEXT PRIMARY KEY,
    created_at REAL NOT NULL,
    updated_at REAL NOT NULL,
    wenshu_version TEXT NOT NULL,
    checksum TEXT
);

-- Chat (migrated from ChatSessionStore)
CREATE TABLE chat_messages (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    source TEXT NOT NULL,  -- 'user' / 'wenshu' / 'system'
    content TEXT NOT NULL,
    timestamp REAL NOT NULL,
    tokens INTEGER,
    thinking TEXT
);

CREATE TABLE chat_summaries (
    session_id TEXT PRIMARY KEY,
    summary TEXT NOT NULL,
    updated_at REAL NOT NULL,
    last_message_id TEXT
);

-- Kanban (migrated from KanbanStore + v0.23 metadata)
CREATE TABLE kanban_tasks (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    status TEXT NOT NULL,
    priority INTEGER NOT NULL DEFAULT 5,
    assignee TEXT,
    started_at REAL,
    completed_at REAL,
    model_override TEXT,
    created_at REAL NOT NULL,
    updated_at REAL NOT NULL
);

-- Sub-agent run trace (v0.23 ticket 006)
CREATE TABLE sub_agent_runs (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    agent_name TEXT NOT NULL,
    title TEXT NOT NULL,
    status TEXT NOT NULL,
    started_at REAL NOT NULL,
    completed_at REAL,
    result_summary TEXT
);

-- Memory (migrated from MemoryStore)
CREATE TABLE memory_entries (
    user_id TEXT NOT NULL,
    memory_id TEXT NOT NULL,
    content TEXT NOT NULL,
    created_at REAL NOT NULL,
    updated_at REAL NOT NULL,
    PRIMARY KEY (user_id, memory_id)
);

-- Skills (migrated from SkillRegistry + v0.23 metadata)
CREATE TABLE skills (
    name TEXT PRIMARY KEY,
    description TEXT NOT NULL,
    source TEXT NOT NULL,
    trust_level TEXT NOT NULL,
    path TEXT NOT NULL,
    installed_at REAL NOT NULL
);

-- Provider keys (migrated from AppleKeychain, encrypted)
CREATE TABLE provider_keys (
    provider_slug TEXT PRIMARY KEY,
    encrypted_key BLOB NOT NULL,  -- encrypted with workspace key
    created_at REAL NOT NULL,
    updated_at REAL NOT NULL
);

-- Preferences (migrated from UserDefaults)
CREATE TABLE preferences (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at REAL NOT NULL
);

-- Books (migrated from FileSystemLibraryStore)
CREATE TABLE books (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    idea TEXT,
    length INTEGER,
    shelf_id TEXT,
    created_at REAL NOT NULL,
    updated_at REAL NOT NULL
);

-- Bookmarks (migrated from BookmarkStore)
CREATE TABLE bookmarks (
    id TEXT PRIMARY KEY,
    book_id TEXT,
    title TEXT NOT NULL,
    note TEXT,
    position INTEGER,
    created_at REAL NOT NULL
);

-- Book outlines (migrated from OutlineExtractor)
CREATE TABLE outline_entries (
    id TEXT PRIMARY KEY,
    book_id TEXT NOT NULL,
    level INTEGER NOT NULL,
    title TEXT NOT NULL,
    line_number INTEGER,
    parent_id TEXT
);

-- Attachments (BLOB or external path)
CREATE TABLE attachments (
    id TEXT PRIMARY KEY,
    parent_table TEXT NOT NULL,  -- 'chat_messages' / 'outline_entries' / etc.
    parent_id TEXT NOT NULL,
    filename TEXT NOT NULL,
    mime_type TEXT NOT NULL,
    size_bytes INTEGER NOT NULL,
    data BLOB,  -- null if external
    external_path TEXT,  -- null if embedded
    created_at REAL NOT NULL
);
```

### File location

```
~/Library/Application Support/wenshu/workspace.ws
```

(macOS Application Support — sandbox-friendly, automatic backup inclusion)

### Migration

When `workspace.ws` doesn't exist:
1. Run migration tool `WenshuWorkspaceMigrator.migrate()`:
   - Read all existing scattered `.sqlite` files
   - Insert into corresponding tables in `workspace.ws`
   - Set manifest.checksum for integrity
2. When `workspace.ws` exists but old schema_version:
   - Run schema migrations in order (v0 → v1 → v2)
3. When `workspace.ws` exists and current schema:
   - Open directly (no migration)

### API surface

```swift
public actor WenshuWorkspace {
    public static let shared = WenshuWorkspace()
    private let dbPath: URL
    private var dbPtr: SQLitePtr

    public func open() throws
    public func close()
    public func backup(to dest: URL) throws       // atomic copy
    public func export(to dest: URL) throws        // full .ws file copy
    public func integrityCheck() -> Bool          // verify checksum
    public func currentSchemaVersion() -> Int
}
```

Plus convenience:
- `WenshuChatStore` / `WenshuKanbanStore` / `WenshuMemoryStore` etc. — thin wrappers that route queries to workspace
- Old stores (`ChatSessionStore` etc.) deprecated but kept as shim during migration period

### Backup / export

```bash
# Atomic backup (within same disk)
cp ~/Library/Application\ Support/wenshu/workspace.ws /Volumes/External/backup-2026-08-23.ws

# Or via app
Menu: File → Export Workspace → Save As...
```

### Performance

- WAL mode: 1 writer + N readers
- Indexes on common query columns (session_id, status, agent_name)
- Single file = single fsync on commit
- Cross-device: just copy the file

## Tickets (8 commits, 1 PR)

| # | Ticket | Effort | Files |
|---|---|---|---|
| 001 | `WenshuWorkspace` actor + schema bootstrap | M | new `Core/Workspace/WenshuWorkspace.swift` + tests |
| 002 | Migration tool (read scattered .sqlite → workspace.ws) | M | new `Core/Workspace/WorkspaceMigrator.swift` + tests |
| 003 | `WenshuChatStore` shim → workspace | S | new + tests |
| 004 | `WenshuKanbanStore` shim → workspace | S | new + tests |
| 005 | `WenshuMemoryStore` shim → workspace | S | new + tests |
| 006 | Backup / Export / Integrity check | S | new + tests |
| 007 | `WenshuWorkspaceMigrator` CLI (wenshu-devtool integration) | S | wenshu-devtool extension |
| 008 | Domain modeling + AGENTS.md update | S | docs |

## Acceptance criteria

- [ ] Single `workspace.ws` file at `~/Library/Application Support/wenshu/workspace.ws`
- [ ] All 7 tables (chat / kanban / sub_agent_runs / memory / skills / provider_keys / preferences / books / bookmarks / outline) populated via migration
- [ ] Backward compat: old `ChatSessionStore.chat.sqlite` etc. still readable during migration window
- [ ] Backup: `cp workspace.ws backup.ws` → restore in different dir → all data accessible
- [ ] Integrity check: workspace checksum verified on open
- [ ] swift test: 544 + new (target 580+) all pass
- [ ] Code-review 2 axes (Standards + Spec)

## Out of scope (deferred to v0.24+)

- Encryption-at-rest (Keychain integration for workspace file itself)
- Cloud sync (iCloud Drive or git LFS)
- Multi-workspace (multiple `.ws` files simultaneously)
- Schema v1 → v2 migration tool (if needed later)

## Risks

- Migration data loss: hermes test DBs (under `~/Library/Application Support/com.wenshu.app/`) might be archived already. Mitigation: keep originals as `.bak` after migration.
- File-level corruption: SQLite WAL can leave orphan -wal / -shm files. Mitigation: integrity check on open + auto-cleanup.
- Concurrent write conflict: WAL mode handles but requires `busy_timeout`. Mitigation: set PRAGMA busy_timeout = 5000.
- macOS sandbox: App may be sandboxed → Application Support not directly writable. Mitigation: defer to v0.24+ if sandbox blocks; current dev runs unsandboxed.

---

*Spec v0.1 · 2026-08-23 pocock · project root = `/Volumes/ANAN/Engineering/wenshu/`*
