//
// RetrievalQualityCorpus.swift · Wenshu · the retrieval quality fixture
//
// A synthetic Chinese corpus, a query set, and one unambiguous anchor per
// query. The corpus is written for this fixture (= no customer text enters
// the repository), and every anchor token occurs in exactly one document, so a
// retrieval hit on the anchor identifies the gold unambiguously.
//
// The corpus carries two halves, and the ratio between them is the whole
// point of it:
//
//   - the documents that answer a question (= the golds)
//   - the documents that share a question's vocabulary without answering it
//     (= the noise). The noise speaks in the same high-frequency words the
//     questions use, so a ranker with no inverse document frequency drowns in
//     it, and the gap between the rankers is the measurement.
//
// Coverage:
//   - The twelve-animal trades (= a question the answer's title names outright)
//   - The star courts, the families and the volume cases (= a question whose
//     answer shares only a rare term with the question = the bridge shape)
//   - Questions that never name the entity they ask about, so the title
//     cannot carry the answer by itself
//
// The fixture measures the RANKING of a corpus, so the document is the unit
// (= the unit the library indexes). See AGENTS.md 4.6 for the search contract
// the ranking has to hold up under.
//

import Foundation

enum RetrievalQualityCorpus {
    /// One indexed document.
    struct Document: Sendable {
        /// The document's path (= the identity a hit carries).
        let path: String
        /// The document's title.
        let title: String
        /// The document's body.
        let body: String
    }

    /// One question, with the file that answers it.
    struct Query: Sendable {
        /// The question, as a person would ask it (= no space-separated keyword
        /// form, so the harness also measures the tokenizer's own job).
        let text: String
        /// The path of the document that answers the question.
        let goldPath: String
        /// A token that occurs in exactly one document of the corpus, so the
        /// gold is unambiguous even when several documents look relevant.
        let anchor: String
        /// What the question demands.
        let kind: Kind

        enum Kind: Sendable {
            /// The answer is in the file the question names outright.
            case direct
            /// The answer sits in a file that shares only a rare term with the
            /// question (= the shape that a query-time expander has to solve).
            case bridge
        }
    }

    // MARK: - The documents that answer a question

    static let answers: [Document] = [
        Document(
            path: "01-生肖/猪-屠户.md",
            title: "猪-屠户",
            body: "商代屠户。卷十二猪案，主角原型是伊尹。职业是屠户，负责三牲祭祀与宰牲之事。"
        ),
        Document(
            path: "01-生肖/鼠-账房仓管.md",
            title: "鼠-账房仓管",
            body: "鼠仓神与谷神同属账房仓管，掌管粮秣与仓储出入。职业是账房，精于算度。"
        ),
        Document(
            path: "01-生肖/兔-红白事大明白.md",
            title: "兔-红白事大明白",
            body: "兔归红白事大明白，专主婚丧嫁娶的仪轨。职业是红白事，主持礼数。"
        ),
        Document(
            path: "01-生肖/猴-优伶.md",
            title: "猴-优伶",
            body: "猴是优伶，粉墨登场，妆点人间百态。收忆者五大家族里的一支，擅长扮作他人。"
        ),
        Document(
            path: "01-生肖/羊-媒婆.md",
            title: "羊-媒婆",
            body: "羊是媒婆，为人说合姻缘，收忆者挡法之一。职业是媒婆，两家奔走。"
        ),
        Document(
            path: "01-生肖/马-驿卒更夫.md",
            title: "马-驿卒更夫",
            body: "马这个地支主管驿卒更夫之职，夜巡报时，兼送信函。"
        ),
        Document(
            path: "01-生肖/牛-太医.md",
            title: "牛-太医",
            body: "牛是太医，望闻问切四诊合参，专治沉疴。"
        ),
        Document(
            path: "02-星君/三台星.md",
            title: "三台星",
            body: "三台星属于天界星君一类的神，是北斗三台，主文章与科名。"
        ),
        Document(
            path: "02-星君/太微星.md",
            title: "太微星",
            body: "太微星为紫微垣之尊，居帝座，统摄星辉。"
        ),
        Document(
            path: "03-家族/收忆者五大家族.md",
            title: "收忆者五大家族",
            body: "收忆者五大家族各有挡法，主宰遗忘与追忆。挡法不同，门户不同。"
        ),
        Document(
            path: "03-家族/挡法.md",
            title: "挡法",
            body: "挡法是收忆者拦下记忆的法门，共五道，各守一门。"
        ),
        Document(
            path: "04-卷案/卷十二猪案.md",
            title: "卷十二猪案",
            body: "卷十二猪案发生在商代都城，猪门一案由此而始。"
        ),
        Document(
            path: "04-卷案/卷九鼠仓案.md",
            title: "卷九鼠仓案",
            body: "卷九鼠仓案记仓神与谷神争仓之始，两家自此分判。"
        ),
        Document(
            path: "05-正文/第一章.md",
            title: "第一章",
            body: "主角入殓师的爷爷是上一代收忆者，身份不明，只留下一枚旧印。"
        ),
        Document(
            path: "05-正文/第七章.md",
            title: "第七章",
            body: "猪在这一章只出现一次，是个市井的影子，谁也说不清他从哪来。"
        ),
        Document(
            path: "06-杂录/星名索引.md",
            title: "星名索引",
            body: "三台星、太微星、太阳星君、秤神，并称四曜，各主一途。"
        ),
        Document(
            path: "06-杂录/商代职官.md",
            title: "商代职官",
            body: "商代职官名录：太医、账房、优伶、媒婆、驿卒、更夫、屠户、红白事大明白皆在其中。"
        ),
        Document(
            path: "06-杂录/十二生肖总论.md",
            title: "十二生肖总论",
            body: "十二生肖各有职业：猪屠户、鼠账房仓管、兔红白事大明白、猴优伶、羊媒婆、马驿卒更夫、牛太医。"
        ),
        Document(
            path: "00-入口/资料库索引.md",
            title: "资料库索引",
            body: "任何问题，先找入口，再跳到具体档案，最后沿反链取全信息。十二生肖各据一门手艺，星君各领一位。"
        ),
    ]

    // MARK: - The documents that speak the same words and answer nothing

    static let noise: [Document] = [
        Document(path: "07-拟/商代职官考.md", title: "商代职官考",
                 body: "商代职官之设，沿袭旧制。太医、账房、媒婆之属，皆见于官册。"),
        Document(path: "07-拟/祭祀考.md", title: "祭祀考",
                 body: "商代祭祀之礼，牺牲用牛羊，礼官掌其仪。"),
        Document(path: "07-拟/生肖源流.md", title: "生肖源流",
                 body: "生肖之序，后世定之。猪居十二之末，位次虽微，其名最著。"),
        Document(path: "07-拟/生肖源流考.md", title: "生肖源流考",
                 body: "生肖与地支相配，猪与亥应。配法有古有今，说各不同。"),
        Document(path: "07-拟/仓神略.md", title: "仓神略",
                 body: "仓神主藏，谷神主出，二者分司。仓中有鼠，神有其职。"),
        Document(path: "07-拟/谷神略.md", title: "谷神略",
                 body: "谷神司出纳，与仓神相维。米麦出仓，皆所经手。"),
        Document(path: "07-拟/神名略说.md", title: "神名略说",
                 body: "星君之号甚多，散见于各处记录，异说并存。"),
        Document(path: "07-拟/北斗略考.md", title: "北斗略考",
                 body: "北斗七政，主枢机。三台列于其中，为辅弼之象。"),
        Document(path: "07-拟/卷案目录.md", title: "卷案目录",
                 body: "卷案目录：卷一至卷三记乡野，卷四至卷九记仓场，卷十以后记大案。"),
        Document(path: "07-拟/卷案目录补.md", title: "卷案目录补",
                 body: "卷案目录补：卷九仓案附考，卷十二大案附考。"),
        Document(path: "07-拟/卷案校记.md", title: "卷案校记",
                 body: "校记：卷九与卷十二两案，年月互有异说。"),
        Document(path: "07-拟/族谱残卷.md", title: "族谱残卷",
                 body: "族谱残卷：收忆者旧有分家之制，其详不可考。"),
        Document(path: "07-拟/族谱残卷二.md", title: "族谱残卷二",
                 body: "族谱残卷二：分家之制，各家门户不同。"),
        Document(path: "07-拟/挡法浅说.md", title: "挡法浅说",
                 body: "挡法之说，见于口传，其名其数，说法不一。"),
        Document(path: "07-拟/婚丧仪注.md", title: "婚丧仪注",
                 body: "婚丧仪注：红白事有专司，仪节繁密，一日不可废。"),
        Document(path: "07-拟/夜巡则例.md", title: "夜巡则例",
                 body: "夜巡则例：更夫按更巡夜，遇事呼报，迟误者有罚。"),
        Document(path: "07-拟/医家四诊.md", title: "医家四诊",
                 body: "四诊合参，医家本色。太医之职，主汤药，不主刀圭。"),
        Document(path: "07-拟/优伶杂记.md", title: "优伶杂记",
                 body: "优伶之戏，衣冠为容，观者或悲或喜，场上人不知。"),
        Document(path: "07-拟/媒婆旧闻.md", title: "媒婆旧闻",
                 body: "媒婆之记，多涉两家姻缘，行话自成一门。"),
        Document(path: "07-拟/商代纪年.md", title: "商代纪年",
                 body: "商代纪年，岁次以王号纪之。卷十二大案在其末年。"),
        Document(path: "07-拟/职官小考.md", title: "职官小考",
                 body: "职官小考：账房之设，掌出纳之籍，日有簿。"),
        Document(path: "07-拟/仓务则例.md", title: "仓务则例",
                 body: "仓务则例：出纳有簿，盘点有期，逾期则罚。"),
        Document(path: "07-拟/神职通考.md", title: "神职通考",
                 body: "神职通考：生肖各有职司，星君各有品位，等第分明。"),
        Document(path: "07-拟/城郭杂记.md", title: "城郭杂记",
                 body: "城郭杂记：城中市肆分区，庙市各占其位。"),
        Document(path: "07-拟/墓志选录.md", title: "墓志选录",
                 body: "墓志选录：商代墓志存世者少，文字多有漫漶。"),
        Document(path: "07-拟/印纹考.md", title: "印纹考",
                 body: "印纹考：旧物之制，篆文阴刻，藏于箧中。"),
        Document(path: "07-拟/收忆说.md", title: "收忆说",
                 body: "收忆之说：其人食忆，所记者久而后淡，淡则归土。"),
        Document(path: "07-拟/入殓行.md", title: "入殓行",
                 body: "入殓之礼，备具而慎之，衣衾之数有定制。"),
        Document(path: "07-拟/猪门考.md", title: "猪门考",
                 body: "猪门之称，或谓其一门，或谓其地，说亦两通。"),
        Document(path: "07-拟/职司分述.md", title: "职司分述",
                 body: "职司分述：屠户、账房、红白事大明白、优伶、媒婆、驿卒，各司其事。"),
        Document(path: "07-拟/商代风俗.md", title: "商代风俗",
                 body: "商代风俗：祭祀、讲信、重农桑，市易以物易物。"),
        Document(path: "07-拟/星野杂记.md", title: "星野杂记",
                 body: "星野杂记：分野之说，起于上古，其详不可考。"),
        Document(path: "07-拟/卷末杂缀.md", title: "卷末杂缀",
                 body: "卷末杂缀：诸案之后，附以零篇，非正文也。"),
        Document(path: "07-拟/门户之别.md", title: "门户之别",
                 body: "门户之别：五家各守其一，不相越，亦不相助。"),
        Document(path: "07-拟/仓神职分.md", title: "仓神职分",
                 body: "仓神职分：主藏者不主出，主出者不主藏，各有所司。"),
        Document(path: "07-拟/谷神职分.md", title: "谷神职分",
                 body: "谷神职分：主出者记其数，主藏者守其物。"),
        Document(path: "07-拟/生肖职司表.md", title: "生肖职司表",
                 body: "生肖职司表：十二门各有所司，其名见于旧册。"),
        Document(path: "07-拟/卷案通考.md", title: "卷案通考",
                 body: "卷案通考：诸案皆有起结，其详分见于各卷。"),
        Document(path: "07-拟/星君品第.md", title: "星君品第",
                 body: "星君品第：位有高下，职有大小，不可乱序。"),
        Document(path: "07-拟/祭祀仪注.md", title: "祭祀仪注",
                 body: "祭祀仪注：礼有等杀，祭有次第，不可乱。"),
    ]

    static let documents: [Document] = answers + noise

    static let queries: [Query] = [
        // A question whose answer's title names the subject outright.
        Query(text: "猪这个生肖在商代是什么职业",
              goldPath: "01-生肖/猪-屠户.md", anchor: "三牲", kind: .direct),
        Query(text: "鼠仓神谷神属于哪个职业",
              goldPath: "01-生肖/鼠-账房仓管.md", anchor: "粮秣", kind: .direct),
        Query(text: "兔归哪个职业管",
              goldPath: "01-生肖/兔-红白事大明白.md", anchor: "仪轨", kind: .direct),
        Query(text: "猴是什么职业",
              goldPath: "01-生肖/猴-优伶.md", anchor: "粉墨", kind: .direct),
        Query(text: "羊是什么职业",
              goldPath: "01-生肖/羊-媒婆.md", anchor: "说合", kind: .direct),
        Query(text: "马这个地支主管什么神职",
              goldPath: "01-生肖/马-驿卒更夫.md", anchor: "报时", kind: .direct),

        // A question that never names the subject, so the title cannot carry
        // the answer and the body has to.
        Query(text: "主持婚丧嫁娶仪轨的是谁",
              goldPath: "01-生肖/兔-红白事大明白.md", anchor: "仪轨", kind: .direct),
        Query(text: "替人扮作他人的是哪一支",
              goldPath: "01-生肖/猴-优伶.md", anchor: "粉墨", kind: .direct),
        Query(text: "夜巡兼送信函的职司是哪一个",
              goldPath: "01-生肖/马-驿卒更夫.md", anchor: "报时", kind: .direct),

        // A question whose answer shares only a rare term with it.
        Query(text: "四曜是哪四位神",
              goldPath: "06-杂录/星名索引.md", anchor: "秤神", kind: .bridge),
        Query(text: "猪案的主角原型是谁",
              goldPath: "01-生肖/猪-屠户.md", anchor: "伊尹", kind: .bridge),
        Query(text: "收忆者五大家族各有什么挡法",
              goldPath: "03-家族/收忆者五大家族.md", anchor: "主宰", kind: .bridge),
    ]
}
