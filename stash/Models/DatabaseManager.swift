import Foundation
import SQLite3

/// Singleton managing all SQLite persistence for Stash.
/// Uses raw SQLite3 C API to avoid external dependency issues during initial setup.
/// Structured for future migration to GRDB or remote database.
final class DatabaseManager: @unchecked Sendable {
    static let shared = DatabaseManager()

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.stash.database", qos: .userInitiated)

    private init() {
        openDatabase()
        createTables()
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - Setup

    private func openDatabase() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let stashDir = appSupport.appendingPathComponent("Stash", isDirectory: true)

        try? fileManager.createDirectory(at: stashDir, withIntermediateDirectories: true)

        let dbPath = stashDir.appendingPathComponent("stash.db").path

        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("[Stash] Failed to open database at \(dbPath)")
        }
    }

    private func createTables() {
        let sql = """
        CREATE TABLE IF NOT EXISTS task (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            tier TEXT NOT NULL DEFAULT 'l1',
            isCompleted INTEGER NOT NULL DEFAULT 0,
            createdAt REAL NOT NULL,
            tierAssignedAt REAL NOT NULL,
            completedAt REAL
        );
        """
        execute(sql)
    }

    // MARK: - CRUD

    func addTask(_ task: StashTask) {
        queue.sync {
            let sql = """
            INSERT INTO task (id, title, tier, isCompleted, createdAt, tierAssignedAt, completedAt)
            VALUES (?, ?, ?, ?, ?, ?, ?);
            """
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, task.id.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                sqlite3_bind_text(stmt, 2, task.title, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                sqlite3_bind_text(stmt, 3, task.tier.rawValue, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                sqlite3_bind_int(stmt, 4, task.isCompleted ? 1 : 0)
                sqlite3_bind_double(stmt, 5, task.createdAt.timeIntervalSince1970)
                sqlite3_bind_double(stmt, 6, task.tierAssignedAt.timeIntervalSince1970)
                if let completedAt = task.completedAt {
                    sqlite3_bind_double(stmt, 7, completedAt.timeIntervalSince1970)
                } else {
                    sqlite3_bind_null(stmt, 7)
                }
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }

    func fetchActiveTasks() -> [StashTask] {
        return queue.sync {
            let sql = "SELECT id, title, tier, isCompleted, createdAt, tierAssignedAt, completedAt FROM task WHERE isCompleted = 0 ORDER BY tierAssignedAt ASC;"
            var tasks: [StashTask] = []
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    if let task = taskFromStatement(stmt) {
                        tasks.append(task)
                    }
                }
            }
            sqlite3_finalize(stmt)
            return tasks
        }
    }

    func fetchCompletedTasks() -> [StashTask] {
        return queue.sync {
            let sql = "SELECT id, title, tier, isCompleted, createdAt, tierAssignedAt, completedAt FROM task WHERE isCompleted = 1 ORDER BY completedAt DESC;"
            var tasks: [StashTask] = []
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    if let task = taskFromStatement(stmt) {
                        tasks.append(task)
                    }
                }
            }
            sqlite3_finalize(stmt)
            return tasks
        }
    }

    func completeTask(id: UUID) {
        queue.sync {
            let sql = "UPDATE task SET isCompleted = 1, completedAt = ? WHERE id = ?;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_double(stmt, 1, Date().timeIntervalSince1970)
                sqlite3_bind_text(stmt, 2, id.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }

    func updateTier(id: UUID, newTier: Tier) {
        queue.sync {
            let sql = "UPDATE task SET tier = ?, tierAssignedAt = ? WHERE id = ?;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, newTier.rawValue, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                sqlite3_bind_double(stmt, 2, Date().timeIntervalSince1970)
                sqlite3_bind_text(stmt, 3, id.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }

    func clearCompleted() {
        execute("DELETE FROM task WHERE isCompleted = 1;")
    }

    func clearAllData() {
        execute("DELETE FROM task;")
    }

    func countActiveTasks(in tier: Tier) -> Int {
        return queue.sync {
            let sql = "SELECT COUNT(*) FROM task WHERE isCompleted = 0 AND tier = ?;"
            var stmt: OpaquePointer?
            var count = 0
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, tier.rawValue, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                if sqlite3_step(stmt) == SQLITE_ROW {
                    count = Int(sqlite3_column_int(stmt, 0))
                }
            }
            sqlite3_finalize(stmt)
            return count
        }
    }

    func exportJSON() -> String? {
        let tasks = fetchActiveTasks() + fetchCompletedTasks()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(tasks) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Helpers

    private func execute(_ sql: String) {
        queue.sync {
            var errMsg: UnsafeMutablePointer<CChar>?
            if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
                if let errMsg = errMsg {
                    print("[Stash DB Error] \(String(cString: errMsg))")
                    sqlite3_free(errMsg)
                }
            }
        }
    }

    private func taskFromStatement(_ stmt: OpaquePointer?) -> StashTask? {
        guard let stmt = stmt else { return nil }

        guard let idStr = sqlite3_column_text(stmt, 0),
              let id = UUID(uuidString: String(cString: idStr)),
              let titlePtr = sqlite3_column_text(stmt, 1),
              let tierPtr = sqlite3_column_text(stmt, 2) else {
            return nil
        }

        let title = String(cString: titlePtr)
        let tierRaw = String(cString: tierPtr)
        let tier = Tier(rawValue: tierRaw) ?? .l1
        let isCompleted = sqlite3_column_int(stmt, 3) != 0
        let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4))
        let tierAssignedAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 5))

        var completedAt: Date?
        if sqlite3_column_type(stmt, 6) != SQLITE_NULL {
            completedAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 6))
        }

        return StashTask(
            id: id,
            title: title,
            tier: tier,
            isCompleted: isCompleted,
            createdAt: createdAt,
            tierAssignedAt: tierAssignedAt,
            completedAt: completedAt
        )
    }
}
