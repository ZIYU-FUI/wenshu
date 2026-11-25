//
//  CitationHonestyTests+Teeth.swift · Wenshu
//
//  The planted cases that prove the citation-honesty guard bites, and the
//  external-tree diagnostic (= the print the disclosure numbers are taken
//  from). The rule, the classifier and the scan they exercise live beside
//  this file in CitationHonestyTests.swift; they are members of the same
//  @Suite, reached through this extension.
//
//  Each teeth case plants its own file under a fresh temporary directory so
//  the six-line URL window of one case can never launder another case's
//  claim, and each names the defect shape it exists to catch.
//
import Foundation
import Testing

extension CitationHonestyTests {
    @Test("Teeth: a planted uncited claim is caught and its cited, negated forms are not")
    func uncitedClaimIsCaught() throws {
        let root = try Self.makeProbeTree("attribution")
        defer { try? FileManager.default.removeItem(at: root) }
        let page = "https://developer.apple.com/design/human-interface-guidelines/sf-symbols"
        // One file per case: the URL window is ±6 lines, so three cases sharing
        // a file would lend each other their citations and all three would pass.
        try Self.write(root.appendingPathComponent("Uncited.swift"), """
        import Foundation
        /// the sidebar row width is Apple canonical and the system ships that number.
        struct Uncited {}
        """)
        try Self.write(root.appendingPathComponent("Cited.swift"), """
        import Foundation
        /// the sidebar row's SF Symbols size is Apple canonical and the system ships that number
        /// (= \(page)).
        struct Cited {}
        """)
        try Self.write(root.appendingPathComponent("Negated.swift"), """
        import Foundation
        /// the HIG publishes no numeric sidebar-row width; the figure is ours.
        struct Negated {}
        """)
        let violations = try Self.scan(sourcesRoot: root)
        // Exactly one of the three: the uncited assertion. The line with the
        // page on it is cited, and the line that denies the page says anything
        // is negated inside its own sentence.
        #expect(violations.count == 1, "expected exactly one planted violation, got: \(violations)")
        #expect(violations.first?.contains("Uncited.swift:2") == true,
                "the violation row should name Uncited.swift line 2: \(violations)")
    }

    @Test("Teeth: a negation in a neighbouring sentence does not launder the claim")
    func negationMustBeInTheSentence() throws {
        let root = try Self.makeProbeTree("sentence")
        defer { try? FileManager.default.removeItem(at: root) }
        try Self.write(root.appendingPathComponent("Probe.swift"), """
        import Foundation
        /// The HIG asks for a distinct tint here. Nothing here is Apple canonical, it is ours.
        /// The HIG asks for a distinct tint here, and the HIG publishes nothing that
        /// says so, so the tint is ours.
        struct Probe {}
        """)
        let violations = try Self.scan(sourcesRoot: root)
        // Line 2 makes a claim about the HIG and denies a different claim in
        // the next sentence, which is not evidence for the first one. Line 3 is
        // the honest form: the negation sits inside the sentence that names the
        // HIG, wrapped across comment lines.
        #expect(violations.count == 1, "expected the neighbouring-sentence denial to be caught, got: \(violations)")
        #expect(violations.first?.contains("Probe.swift:2") == true, "\(violations)")
    }

    @Test("Teeth: the widened reading charges what the case-sensitive one was blind to, and nothing it was not")
    func widenedReadingTeeth() throws {
        let root = try Self.makeProbeTree("widen")
        defer { try? FileManager.default.removeItem(at: root) }
        // (a) The casing the old scan could not see at all.
        try Self.write(root.appendingPathComponent("Hidden.swift"), """
        import Foundation
        /// THE HIG fixes this spacing.
        struct Hidden {}
        """)
        // (b) The prose noise an unanchored case-insensitive scan counts:
        // "the HIG" firing inside "the highlight" made the old case-sensitive
        // reading's headline number untrustworthy.
        try Self.write(root.appendingPathComponent("Noise.swift"), """
        import Foundation
        /// the highlight sits higher than the header row.
        struct Noise {}
        """)
        // (c) Proximity is not citation: a live Apple URL whose subject the
        // sentence never mentions may not credit the claim.
        try Self.write(root.appendingPathComponent("OffTopic.swift"), """
        import Foundation
        /// the sidebar row width is Apple canonical.
        /// (https://developer.apple.com/documentation/appkit/nsmenu)
        struct OffTopic {}
        """)
        // (d) The honest wrap: the denial lands on the next comment line, which
        // a window ending at the hit line could not read.
        try Self.write(root.appendingPathComponent("Wrapped.swift"), """
        import Foundation
        /// The HIG's chapter on toolbars publishes
        /// no toolbar inset table.
        struct Wrapped {}
        """)
        let violations = try Self.scan(sourcesRoot: root)
        #expect(violations.contains(where: { $0.contains("Hidden.swift:2") }),
                "the widened matcher must charge the casing-hidden claim: \(violations)")
        #expect(!violations.contains(where: { $0.contains("Noise.swift") }),
                "word-anchoring must not charge 'highlight'/'higher' as HIG claims: \(violations)")
        #expect(violations.contains(where: { $0.contains("OffTopic.swift:2") }),
                "an off-topic URL in the window must not credit the claim: \(violations)")
        #expect(!violations.contains(where: { $0.contains("Wrapped.swift") }),
                "a denial wrapped onto the next comment line must still count: \(violations)")
    }

    @Test("Teeth: an orphaned .md citation is caught by the orphan rule itself")
    func orphanRuleIsCaught() throws {
        let root = try Self.makeProbeTree("orphan")
        defer { try? FileManager.default.removeItem(at: root) }
        let page = "https://developer.apple.com/design/human-interface-guidelines/sf-symbols"
        let lean = "https://developer.apple.com/documentation/appkit/nsmenu"
        try Self.write(root.appendingPathComponent("Notes/Doc.md"), """
        # doc

        Quotes \(page) as Apple's rule.
        And \(lean), which the code really does lean on.
        """)
        try Self.write(root.appendingPathComponent("Code/Real.swift"), "import Foundation\n// see \(lean)\n")
        let swiftURLs = Self.collectURLs(in: root, ext: "swift")
        #expect(swiftURLs == Set([lean]), "the .swift collector read: \(swiftURLs)")
        var orphans: [String] = []
        for (file, line, found) in Self.urlOccurrences(in: root, ext: "md") where !swiftURLs.contains(found) {
            orphans.append("\(file):\(line)")
        }
        #expect(orphans.count == 1, "the orphaned .md citation was not caught: \(orphans)")
        #expect(orphans.first?.contains("Doc.md:3") == true, "\(orphans)")
    }

    /// Diagnostic: the same scan over a tree named by `WENSHU_CITATION_ROOT`,
    /// so the guard can be run against a checkout that is not the working one
    /// (= a review reading "what does the rule say about the tree before this
    /// change"). Silent when the variable is unset, so the normal run is
    /// unaffected.
    @Test("Diagnostic: scan a tree named by WENSHU_CITATION_ROOT")
    func scanExternalTree() throws {
        guard let path = ProcessInfo.processInfo.environment["WENSHU_CITATION_ROOT"] else { return }
        let root = URL(fileURLWithPath: path)
        let violations = try Self.scan(sourcesRoot: root)
        let counts = Self.attributionHitCounts(root)
        print("EXTERNAL SCAN \(path)")
        print("attribution lines: exact(case-sensitive) \(counts.exactCaseSensitive)"
            + " | anchored(case-insensitive) \(counts.anchoredCaseInsensitive)"
            + " | uncited: \(violations.count)")
        for v in violations {
            print("  " + v)
        }
    }

    @Test("Teeth: the classifier's four verdicts, one planted case each")
    func classifierVerdicts() {
        let planted = "the SF Symbols sidebar glyph size is Apple canonical."
        let page = "https://developer.apple.com/design/human-interface-guidelines/sf-symbols"
        #expect(Self.classify(sentence: planted, window: [planted], file: "Probe.swift") == .violation)
        #expect(Self.classify(sentence: planted, window: [planted, "// \(page)"],
                              file: "Probe.swift") == .cited)
        #expect(Self.classify(sentence: "the HIG publishes no such number.",
                              window: ["the HIG publishes no such number."],
                              file: "Probe.swift") == .negation)
        #expect(Self.classify(sentence: planted, window: [planted],
                              file: "WenshuApp/Shared/UI/ComponentDocs/SFRegions.md") == .namedException)
    }
}
