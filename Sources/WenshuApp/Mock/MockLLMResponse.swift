// MockLLMResponse.swift · 文枢 (Wenshu) · v0.01.0 WO-004
//
// In-memory view types + mock LLM responses.
//
// Why mock?
// - WO-004 is the UI-flow phase. The user journey (create project → write
//   one-sentence story → AI 举一反三 → pick directions → see character +
//   world skeleton) needs to be demoable without an LLM key.
// - LLM key is configured by the user in macOS Keychain; PM-direct (and
//   CI) does not have it. Mock keeps the demo reproducible.
// - WO-005 swaps the mock streams for `LLMService.streamChat(...)` once
//   the user has configured their key. The `AsyncThrowingStream<String, Error>`
//   shape is identical, so the ChatViewModel doesn't change.
//
// All types here are view-layer only (no CoreData). They get replaced by
// CoreData entities in WO-005+ once `.ws` round-tripping lands.

import Foundation

// MARK: - View-layer data types

/// One message in the chat. `isStreaming` is true while the AI is still
/// generating text. `role` is `"user"` or `"assistant"` (matches the
/// protocol assumed by `MinimaxProvider`).
struct ChatMessage: Identifiable, Hashable, Sendable {
    let id: UUID
    let role: String
    var content: String
    var isStreaming: Bool

    init(
        id: UUID = UUID(),
        role: String,
        content: String,
        isStreaming: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.isStreaming = isStreaming
    }
}

/// One AI-suggested 举一反三 direction. Grouped by `category` in the UI.
struct ExpandOption: Identifiable, Hashable, Sendable {
    let id: UUID
    let category: String
    let title: String
    let description: String

    init(
        id: UUID = UUID(),
        category: String,
        title: String,
        description: String
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.description = description
    }
}

/// Display-only character card. WO-005 swaps this for `CDCharacter`.
struct CharacterSnapshot: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let role: String
    let backstory: String

    init(
        id: UUID = UUID(),
        name: String,
        role: String,
        backstory: String
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.backstory = backstory
    }
}

/// Display-only world rule. WO-005 swaps this for `CDWorldRule`.
struct WorldRuleSnapshot: Identifiable, Hashable, Sendable {
    let id: UUID
    let rule: String
    let category: String

    init(
        id: UUID = UUID(),
        rule: String,
        category: String
    ) {
        self.id = id
        self.rule = rule
        self.category = category
    }
}

// MARK: - Mock LLM responses

/// Static mock responses. The streaming variants return `String` chunks so
/// the ChatViewModel can append them one at a time and fake a typewriter
/// effect (`Task.sleep` between chunks).
enum MockLLMResponse {

    // First reply: explains to the user that four categories of directions
    // are coming. Real LLM would generate the directions inline; we split.
    static let initialReply = """
    好故事！让我从四个维度帮你展开联想——核心冲突、主角延伸、世界观缺口、发展方向。\
    每个维度我都给你几个候选方向，请挑选 2-3 个我们继续往下走。
    """

    // Reply after the user confirms their direction picks.
    static let confirmationReply = """
    已收到你的选择。接下来让我为你构建人物与世界骨架——主角、2 位配角、3-4 条世界规则。\
    稍等片刻。
    """

    /// Split a string into N-character chunks for typewriter streaming.
    static func streamingChunks(of text: String, size: Int = 3) -> [String] {
        var chunks: [String] = []
        var index = text.startIndex
        while index < text.endIndex {
            let end = text.index(index, offsetBy: size, limitedBy: text.endIndex) ?? text.endIndex
            chunks.append(String(text[index..<end]))
            index = end
        }
        return chunks
    }

    /// 4 categories × 2-3 options = 10 candidates.
    static func expandOptions() -> [ExpandOption] {
        return [
            // 核心冲突 (2)
            ExpandOption(
                category: "核心冲突",
                title: "主角发现身世真相",
                description: "主角在旧物中翻出被封印的信件，揭开一段被掩盖的家族秘密。"
            ),
            ExpandOption(
                category: "核心冲突",
                title: "主角被陷害入狱",
                description: "主角被诬陷犯下重罪，所有人远离他，他必须从囚笼中翻盘。"
            ),
            // 主角延伸 (3)
            ExpandOption(
                category: "主角延伸",
                title: "童年阴影浮现",
                description: "主角幼年目睹亲人离去，潜意识里埋着挥之不去的噩梦。"
            ),
            ExpandOption(
                category: "主角延伸",
                title: "师父临终嘱托",
                description: "师父临终前留下一句没说完的话，成为主角追寻的线索。"
            ),
            ExpandOption(
                category: "主角延伸",
                title: "失踪的妹妹",
                description: "主角的妹妹自幼失踪，多年后才出现一张模糊的画像。"
            ),
            // 世界观缺口 (2)
            ExpandOption(
                category: "世界观缺口",
                title: "隐藏的魔法体系曝光",
                description: "大陆上流传的禁咒被主角无意中唤醒，引发连锁反应。"
            ),
            ExpandOption(
                category: "世界观缺口",
                title: "古代王国遗迹",
                description: "勘探队在地底发现远古帝国的遗迹，里头藏有改变格局的力量。"
            ),
            // 发展方向 (3)
            ExpandOption(
                category: "发展方向",
                title: "开放式结局",
                description: "故事在最关键处戛然而止，让读者自行补完后续。"
            ),
            ExpandOption(
                category: "发展方向",
                title: "悬念铺垫",
                description: "埋下第二条故事线，让读者预感风暴将至。"
            ),
            ExpandOption(
                category: "发展方向",
                title: "主角觉醒",
                description: "主角在绝境中爆发出前所未有的力量，触发内心深处的蜕变。"
            ),
        ]
    }

    /// 1 主角 + 2 配角 (3 total).
    static func characters() -> [CharacterSnapshot] {
        return [
            CharacterSnapshot(
                name: "林渊",
                role: "主角",
                backstory: "本是边陲小镇的孤儿，某日收到无名信物后卷入江湖纷争。看似温吞却藏锋，内心深处埋着一段连自己都不记得的过去。"
            ),
            CharacterSnapshot(
                name: "苏锦",
                role: "青梅竹马",
                backstory: "主角幼年唯一的玩伴，长大后成为客栈女掌柜。八面玲珑的外表下守着不可言说的秘密。"
            ),
            CharacterSnapshot(
                name: "沈望",
                role: "师父/对头",
                backstory: "以一己之力在正邪之间周旋的老江湖，对主角既期许又忌惮。临终前留下一句没说完的话。"
            ),
        ]
    }

    /// 4 条世界规则。
    static func worldRules() -> [WorldRuleSnapshot] {
        return [
            WorldRuleSnapshot(
                rule: "玄气为本，剑意为骨。修炼者需以剑意牵引玄气，方可入上境。",
                category: "修炼体系"
            ),
            WorldRuleSnapshot(
                rule: "江湖门派以令牌为信，伪造令牌者将受全江湖追杀。",
                category: "社会规则"
            ),
            WorldRuleSnapshot(
                rule: "古遗迹一旦开启便不可逆，开启时当地必有天气异象。",
                category: "禁咒"
            ),
            WorldRuleSnapshot(
                rule: "突破瓶颈需以心象为引，心中无惧才可入上境。",
                category: "修炼体系"
            ),
        ]
    }
}
