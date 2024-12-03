import Foundation
import SQLite3
import os.log

enum Vault {
    enum DatabaseError: LocalizedError {
        case openFailed(String)
        case closeFailed(String)
        case prepareFailed(String)
        case executionFailed(String)
        case queryFailed(String)
        case invalidData(String)
        case fileSystemError(String)
        
        var errorDescription: String? {
            switch self {
            case .openFailed(let reason):
                return "Failed to open database: \(reason)"
            case .closeFailed(let reason):
                return "Failed to close database: \(reason)"
            case .prepareFailed(let reason):
                return "Failed to prepare SQL statement: \(reason)"
            case .executionFailed(let reason):
                return "Failed to execute SQL statement: \(reason)"
            case .queryFailed(let reason):
                return "Query failed: \(reason)"
            case .invalidData(let reason):
                return "Invalid data: \(reason)"
            case .fileSystemError(let reason):
                return "File system error: \(reason)"
            }
        }
    }

    class DatabaseManager {
        static let shared = DatabaseManager()
        private var db: OpaquePointer?
        private let logger = Logger(subsystem: "com.dynasty.DatabaseManager", category: "Database")
        private let fileManager = FileManager.default
        private let queue = DispatchQueue(label: "com.dynasty.DatabaseManager.queue")
        
        private init() {}
        
        func openDatabase() throws {
            logger.info("Opening database")
            
            // Close existing database if open
            if db != nil {
                closeDatabase()
            }
            
            let fileURL = try fileManager
                .urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("vault.sqlite3")
            
            // Ensure directory exists
            let directory = fileURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: directory.path) {
                do {
                    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                } catch {
                    logger.error("Failed to create database directory: \(error.localizedDescription)")
                    throw DatabaseError.fileSystemError("Failed to create directory: \(error.localizedDescription)")
                }
            }
            
            // Set pragmas for better memory handling
            var flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE
            if sqlite3_open_v2(fileURL.path, &db, flags, nil) != SQLITE_OK {
                let error = String(cString: sqlite3_errmsg(db))
                logger.error("Error opening database: \(error)")
                throw DatabaseError.openFailed(error)
            }
            
            // Configure database settings for better memory management
            let pragmas = [
                "PRAGMA journal_mode = WAL",
                "PRAGMA synchronous = NORMAL",
                "PRAGMA cache_size = 2000",
                "PRAGMA temp_store = MEMORY",
                "PRAGMA mmap_size = 30000000000",
                "PRAGMA page_size = 4096",
                "PRAGMA auto_vacuum = INCREMENTAL"
            ]
            
            for pragma in pragmas {
                if sqlite3_exec(db, pragma, nil, nil, nil) != SQLITE_OK {
                    let error = String(cString: sqlite3_errmsg(db))
                    logger.error("Failed to set pragma \(pragma): \(error)")
                }
            }
            
            try createTables()
            logger.info("Database opened successfully")
        }
        
        func closeDatabase() {
            queue.sync {
                logger.info("Closing database")
                
                if let db = db {
                    // Finalize all statements
                    var stmt: OpaquePointer?
                    while (sqlite3_next_stmt(db, nil) != nil) {
                        if let stmt = sqlite3_next_stmt(db, nil) {
                            sqlite3_finalize(stmt)
                        }
                    }
                    
                    // Cleanup WAL files
                    let _ = try? sqlite3_exec(db, "PRAGMA wal_checkpoint(TRUNCATE)", nil, nil, nil)
                    
                    if sqlite3_close(db) != SQLITE_OK {
                        let error = String(cString: sqlite3_errmsg(db))
                        logger.error("Error closing database: \(error)")
                        return
                    }
                    self.db = nil
                    logger.info("Successfully closed database")
                }
            }
        }
        
        func createTables() throws {
            logger.info("Creating database tables")
            
            let createTableString = """
                CREATE TABLE IF NOT EXISTS vault_items(
                    id TEXT PRIMARY KEY,
                    user_id TEXT,
                    title TEXT,
                    description TEXT,
                    file_type TEXT,
                    encrypted_file_name TEXT,
                    storage_path TEXT,
                    thumbnail_url TEXT,
                    metadata TEXT,
                    created_at TEXT,
                    updated_at TEXT,
                    is_deleted INTEGER DEFAULT 0
                );
            """
            
            var createTableStatement: OpaquePointer?
            defer {
                sqlite3_finalize(createTableStatement)
            }
            
            if sqlite3_prepare_v2(db, createTableString, -1, &createTableStatement, nil) != SQLITE_OK {
                let error = String(cString: sqlite3_errmsg(db))
                logger.error("CREATE TABLE statement could not be prepared: \(error)")
                throw DatabaseError.prepareFailed(error)
            }
            
            if sqlite3_step(createTableStatement) != SQLITE_DONE {
                let error = String(cString: sqlite3_errmsg(db))
                logger.error("Failed to create vault items table: \(error)")
                throw DatabaseError.executionFailed(error)
            }
            
            logger.info("Successfully created vault items table")
        }
        
        func fetchItems() async throws -> [VaultItem] {
            return try await withCheckedThrowingContinuation { continuation in
                queue.async {
                    autoreleasepool {
                        do {
                            let items = try self.fetchItemsSync()
                            continuation.resume(returning: items)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            }
        }
        
        private func fetchItemsSync() throws -> [VaultItem] {
            logger.info("Fetching vault items")
            
            let queryString = "SELECT * FROM vault_items ORDER BY created_at DESC;"
            var queryStatement: OpaquePointer?
            var items: [VaultItem] = []
            
            defer {
                sqlite3_finalize(queryStatement)
            }
            
            if sqlite3_prepare_v2(db, queryString, -1, &queryStatement, nil) != SQLITE_OK {
                let error = String(cString: sqlite3_errmsg(db))
                logger.error("Failed to prepare fetch query: \(error)")
                throw DatabaseError.prepareFailed(error)
            }
            
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                autoreleasepool {
                    do {
                        let item = try extractVaultItem(from: queryStatement)
                        items.append(item)
                    } catch {
                        logger.error("Failed to extract vault item: \(error.localizedDescription)")
                    }
                }
            }
            
            logger.info("Successfully fetched \(items.count) vault items")
            return items
        }
        
        private func extractVaultItem(from statement: OpaquePointer?) throws -> VaultItem {
            guard let statement = statement else {
                throw DatabaseError.invalidData("Invalid statement")
            }
            
            return try autoreleasepool {
                guard let id = sqlite3_column_text(statement, 0).map({ String(cString: $0) }),
                      let userId = sqlite3_column_text(statement, 1).map({ String(cString: $0) }),
                      let title = sqlite3_column_text(statement, 2).map({ String(cString: $0) }),
                      let fileTypeStr = sqlite3_column_text(statement, 4).map({ String(cString: $0) }),
                      let encryptedFileName = sqlite3_column_text(statement, 5).map({ String(cString: $0) }),
                      let storagePath = sqlite3_column_text(statement, 6).map({ String(cString: $0) }),
                      let metadataString = sqlite3_column_text(statement, 8).map({ String(cString: $0) }),
                      let createdAtStr = sqlite3_column_text(statement, 9).map({ String(cString: $0) }),
                      let updatedAtStr = sqlite3_column_text(statement, 10).map({ String(cString: $0) }),
                      let fileType = VaultItemType(rawValue: fileTypeStr),
                      let metadata = try? JSONDecoder().decode(VaultItemMetadata.self, from: Data(metadataString.utf8)),
                      let createdAt = ISO8601DateFormatter().date(from: createdAtStr),
                      let updatedAt = ISO8601DateFormatter().date(from: updatedAtStr) else {
                    throw DatabaseError.invalidData("Failed to extract VaultItem data from database")
                }
                
                let description = sqlite3_column_text(statement, 3).map { String(cString: $0) }
                let thumbnailURL = sqlite3_column_text(statement, 7).map { String(cString: $0) }
                let isDeleted = sqlite3_column_int(statement, 11) != 0
                
                return VaultItem(
                    id: id,
                    userId: userId,
                    title: title,
                    description: description,
                    fileType: fileType,
                    encryptedFileName: encryptedFileName,
                    storagePath: storagePath,
                    thumbnailURL: thumbnailURL,
                    metadata: metadata,
                    createdAt: createdAt,
                    updatedAt: updatedAt,
                    isDeleted: isDeleted
                )
            }
        }
        
        func saveItems(_ items: [VaultItem]) async throws {
            try await withCheckedThrowingContinuation { continuation in
                queue.async {
                    autoreleasepool {
                        do {
                            try self.saveItemsSync(items)
                            continuation.resume()
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            }
        }
        
        private func saveItemsSync(_ items: [VaultItem]) throws {
            logger.info("Saving \(items.count) vault items")
            
            let insertString = """
                INSERT OR REPLACE INTO vault_items (
                    id, user_id, title, description, file_type,
                    encrypted_file_url, thumbnail_url, metadata,
                    created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
            
            var insertStatement: OpaquePointer?
            defer {
                sqlite3_finalize(insertStatement)
            }
            
            if sqlite3_prepare_v2(db, insertString, -1, &insertStatement, nil) != SQLITE_OK {
                let error = String(cString: sqlite3_errmsg(db))
                logger.error("Failed to prepare insert statement: \(error)")
                throw DatabaseError.prepareFailed(error)
            }
            
            // Begin transaction
            if sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil) != SQLITE_OK {
                let error = String(cString: sqlite3_errmsg(db))
                logger.error("Failed to begin transaction: \(error)")
                throw DatabaseError.executionFailed(error)
            }
            
            do {
                for item in items {
                    try autoreleasepool {
                        try bindVaultItem(item, to: insertStatement)
                        
                        if sqlite3_step(insertStatement) != SQLITE_DONE {
                            let error = String(cString: sqlite3_errmsg(db))
                            logger.error("Failed to insert item \(item.id): \(error)")
                            throw DatabaseError.executionFailed(error)
                        }
                        
                        sqlite3_reset(insertStatement)
                    }
                }
                
                // Commit transaction
                if sqlite3_exec(db, "COMMIT", nil, nil, nil) != SQLITE_OK {
                    let error = String(cString: sqlite3_errmsg(db))
                    logger.error("Failed to commit transaction: \(error)")
                    throw DatabaseError.executionFailed(error)
                }
                
                logger.info("Successfully saved all vault items")
            } catch {
                // Rollback transaction on error
                if sqlite3_exec(db, "ROLLBACK", nil, nil, nil) != SQLITE_OK {
                    logger.error("Failed to rollback transaction")
                }
                throw error
            }
        }
        
        private func bindVaultItem(_ item: VaultItem, to statement: OpaquePointer?) throws {
            guard let statement = statement else {
                throw DatabaseError.invalidData("Invalid statement")
            }
            
            let encoder = JSONEncoder()
            let metadataData = try encoder.encode(item.metadata)
            guard let metadataString = String(data: metadataData, encoding: .utf8) else {
                throw DatabaseError.invalidData("Failed to encode metadata")
            }
            
            let dateFormatter = ISO8601DateFormatter()
            let createdAtString = dateFormatter.string(from: item.createdAt)
            let updatedAtString = dateFormatter.string(from: item.updatedAt)
            
            // Bind values in order of columns
            sqlite3_bind_text(statement, 1, NSString(string: item.id).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, NSString(string: item.userId).utf8String, -1, nil)
            sqlite3_bind_text(statement, 3, NSString(string: item.title).utf8String, -1, nil)
            if let description = item.description {
                sqlite3_bind_text(statement, 4, NSString(string: description).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(statement, 4)
            }
            sqlite3_bind_text(statement, 5, NSString(string: item.fileType.rawValue).utf8String, -1, nil)
            sqlite3_bind_text(statement, 6, NSString(string: item.encryptedFileName).utf8String, -1, nil)
            sqlite3_bind_text(statement, 7, NSString(string: item.storagePath).utf8String, -1, nil)
            if let thumbnailURL = item.thumbnailURL {
                sqlite3_bind_text(statement, 8, NSString(string: thumbnailURL).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(statement, 8)
            }
            sqlite3_bind_text(statement, 9, NSString(string: metadataString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 10, NSString(string: createdAtString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 11, NSString(string: updatedAtString).utf8String, -1, nil)
            sqlite3_bind_int(statement, 12, item.isDeleted ? 1 : 0)
        }
        
        deinit {
            closeDatabase()
        }
    }
} 
