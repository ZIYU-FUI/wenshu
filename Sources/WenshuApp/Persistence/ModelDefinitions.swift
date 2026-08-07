import CoreData

func makeWenshuModel() -> NSManagedObjectModel {
    let model = NSManagedObjectModel()

    func attribute(_ name: String, _ type: NSAttributeType, optional: Bool = false, defaultValue: Any? = nil) -> NSAttributeDescription {
        let result = NSAttributeDescription()
        result.name = name
        result.attributeType = type
        result.isOptional = optional
        result.defaultValue = defaultValue
        return result
    }

    func entity(_ name: String, properties: [NSPropertyDescription]) -> NSEntityDescription {
        let result = NSEntityDescription()
        result.name = name
        result.managedObjectClassName = "NSManagedObject"
        result.properties = properties
        return result
    }

    model.entities = [
        entity("CDCharacter", properties: [
            attribute("name", .stringAttributeType),
            attribute("role", .stringAttributeType, optional: true),
            attribute("backstory", .stringAttributeType, optional: true),
            attribute("createdAt", .dateAttributeType)
        ]),
        entity("CDChapter", properties: [
            attribute("title", .stringAttributeType),
            attribute("content", .stringAttributeType, optional: true),
            attribute("chapterIndex", .integer32AttributeType),
            attribute("createdAt", .dateAttributeType)
        ]),
        entity("CDNote", properties: [
            attribute("text", .stringAttributeType),
            attribute("createdAt", .dateAttributeType),
            attribute("tags", .stringAttributeType, optional: true)
        ]),
        entity("CDWorldRule", properties: [
            attribute("rule", .stringAttributeType),
            attribute("category", .stringAttributeType, optional: true),
            attribute("createdAt", .dateAttributeType)
        ]),
        entity("CDForeshadow", properties: [
            attribute("hook", .stringAttributeType),
            attribute("status", .stringAttributeType, optional: true),
            attribute("plantedAt", .dateAttributeType),
            attribute("resolvedAt", .dateAttributeType, optional: true)
        ]),
        entity("CDRevision", properties: [
            attribute("originalChapterID", .UUIDAttributeType),
            attribute("revisedContent", .stringAttributeType, optional: true),
            attribute("reason", .stringAttributeType, optional: true),
            attribute("createdAt", .dateAttributeType),
            attribute("accepted", .booleanAttributeType, defaultValue: false)
        ]),
        entity("CDAIDraft", properties: [
            attribute("prompt", .stringAttributeType),
            attribute("draft", .stringAttributeType, optional: true),
            attribute("model", .stringAttributeType),
            attribute("createdAt", .dateAttributeType),
            attribute("finalizedChapterID", .UUIDAttributeType, optional: true)
        ])
    ]
    return model
}
