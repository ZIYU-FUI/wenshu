import CoreData

@MainActor
final class PersistenceController: ObservableObject {
    static let shared = PersistenceController()

    let container: NSPersistentContainer
    let storeActor: WenshuStoreActor

    init() {
        container = NSPersistentContainer(name: "Wenshu", managedObjectModel: makeWenshuModel())
        storeActor = WenshuStoreActor(container: container)
        container.persistentStoreDescriptions = [NSPersistentStoreDescription()]
    }
}
