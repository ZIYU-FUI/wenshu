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
            attribute("resolvedAt", .dateAttributeType, optional: true),
            // LT-02 v2 新增 — AIF 8/10 拍板: 加可空关联字段,旧 .ws 自动迁移可读。
            // 装机 user 选中段落联动 = inspector 伏笔 tab 真读 (按 chapter / paragraph ID 过滤)。
            // 严禁删/改既有 4 字段 (AGENTS §12 红线 — schema 加可空字段 OK,
            // 改字段类型 / 删字段要 PM 拍)。
            attribute("chapterID", .UUIDAttributeType, optional: true),
            attribute("paragraphID", .UUIDAttributeType, optional: true)
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
        ]),
        // WO-LT-01: 5-zone layout state (AGENTS.md §8.1).
        // Per LT-01 spec the entity carries exactly 2 string columns — JSON
        // blobs — for the 5 panels' collapsed/expanded flags and the 5
        // splitter ratios. See Sources/WenshuApp/Models/LayoutState.swift
        // for the in-memory Codable representation.
        //
        // "不动 现有 7 个 entity" per LT-01 spec: only ADD this one.
        entity("CDLayoutState", properties: [
            attribute("panel_states", .stringAttributeType, optional: true, defaultValue: ""),
            attribute("panel_ratios", .stringAttributeType, optional: true, defaultValue: "")
        ])
    ]
    return model
}
