import CoreData
import Foundation

actor WenshuStoreActor {
    static let shared = WenshuStoreActor()

    let container: NSPersistentContainer

    init(container: NSPersistentContainer? = nil) {
        let persistentContainer = container ?? NSPersistentContainer(name: "Wenshu", managedObjectModel: makeWenshuModel())
        if container == nil {
            let directory = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Documents", isDirectory: true)
                .appendingPathComponent("wenshu-projects", isDirectory: true)
            persistentContainer.persistentStoreDescriptions = [
                NSPersistentStoreDescription(url: directory.appendingPathComponent("Wenshu.sqlite"))
            ]
        }
        self.container = persistentContainer
    }

    func createCharacter(_ values: [String: Any]) async throws {
        let context = container.viewContext
        try await context.perform {
            let object = NSEntityDescription.insertNewObject(forEntityName: "CDCharacter", into: context)
            for (key, value) in values { object.setValue(value, forKey: key) }
            if object.value(forKey: "createdAt") == nil { object.setValue(Date(), forKey: "createdAt") }
        }
    }

    func listCharacters() async throws -> [String] {
        let context = container.viewContext
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "CDCharacter")
            return try context.fetch(request).compactMap { $0.value(forKey: "name") as? String }
        }
    }

    func createNote(_ values: [String: Any]) async throws {
        let context = container.viewContext
        try await context.perform {
            let object = NSEntityDescription.insertNewObject(forEntityName: "CDNote", into: context)
            for (key, value) in values { object.setValue(value, forKey: key) }
            if object.value(forKey: "createdAt") == nil { object.setValue(Date(), forKey: "createdAt") }
        }
    }

    func listNotes() async throws -> [String] {
        let context = container.viewContext
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "CDNote")
            return try context.fetch(request).compactMap { $0.value(forKey: "text") as? String }
        }
    }

    func createWorldRule(_ values: [String: Any]) async throws {
        let context = container.viewContext
        try await context.perform {
            let object = NSEntityDescription.insertNewObject(forEntityName: "CDWorldRule", into: context)
            for (key, value) in values { object.setValue(value, forKey: key) }
            if object.value(forKey: "createdAt") == nil { object.setValue(Date(), forKey: "createdAt") }
        }
    }

    func countAll() async throws -> Int {
        let context = container.viewContext
        return try await context.perform {
            try ["CDCharacter", "CDChapter", "CDNote", "CDWorldRule", "CDForeshadow", "CDRevision", "CDAIDraft"].reduce(0) { total, name in
                let request = NSFetchRequest<NSManagedObject>(entityName: name)
                let count = try context.count(for: request)
                return total + count
            }
        }
    }
}
