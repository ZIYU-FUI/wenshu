//
//  FileSafetyTests.swift · Wenshu · v0.23 ticket 013.002 (hermes gap 2)
//
//  Boss 2026-08-23 拍: hermes _is_blocked_device + symlink hop parity.
//

import Foundation
import Testing
@testable import WenshuApp

@Suite("FileSafety (hermes _is_blocked_device + symlink hop parity)")
struct FileSafetyTests {

    // MARK: - isBlockedDevice

    @Test("/dev/stdin → blocked (can hang reads)")
    func testDevStdinBlocked() {
        let tools = FileTools()
        #expect(tools.isBlockedDevice("/dev/stdin"))
    }

    @Test("/dev/zero → blocked (infinite stream)")
    func testDevZeroBlocked() {
        let tools = FileTools()
        #expect(tools.isBlockedDevice("/dev/zero"))
    }

    @Test("/proc/self/environ → blocked (env var leak)")
    func testProcEnvironBlocked() {
        let tools = FileTools()
        #expect(tools.isBlockedDevice("/proc/self/environ"))
    }

    @Test("/proc/self/maps → blocked (ASLR bypass)")
    func testProcMapsBlocked() {
        let tools = FileTools()
        #expect(tools.isBlockedDevice("/proc/self/maps"))
    }

    @Test("/proc/self/mem → blocked (raw memory)")
    func testProcMemBlocked() {
        let tools = FileTools()
        #expect(tools.isBlockedDevice("/proc/self/mem"))
    }

    @Test("/proc/self/cmdline → blocked (process args)")
    func testProcCmdlineBlocked() {
        let tools = FileTools()
        #expect(tools.isBlockedDevice("/proc/self/cmdline"))
    }

    @Test("/proc/self/auxv → blocked (AT_RANDOM oracle)")
    func testProcAuxvBlocked() {
        let tools = FileTools()
        #expect(tools.isBlockedDevice("/proc/self/auxv"))
    }

    @Test("/proc/self/pagemap → blocked (memory translation)")
    func testProcPagemapBlocked() {
        let tools = FileTools()
        #expect(tools.isBlockedDevice("/proc/self/pagemap"))
    }

    @Test("/proc/fd/0 → blocked (stdio)")
    func testProcFd0Blocked() {
        let tools = FileTools()
        #expect(tools.isBlockedDevice("/proc/self/fd/0"))
    }

    @Test("/proc/cpuinfo → allowed (not sensitive)")
    func testProcCpuinfoAllowed() {
        let tools = FileTools()
        #expect(!tools.isBlockedDevice("/proc/cpuinfo"))
    }

    @Test("/tmp/legit.txt → allowed (not /dev or /proc)")
    func testTmpAllowed() {
        let tools = FileTools()
        #expect(!tools.isBlockedDevice("/tmp/legit.txt"))
    }

    // MARK: - pathDenied (existing behavior still works)

    @Test("pathDenied: Sources/ → blocked (existing behavior)")
    func testPathDeniedSources() {
        let tools = FileTools()
        #expect(tools.pathDenied("./Sources/foo.swift"))
    }

    @Test("pathDenied: .scratch/ → blocked (existing behavior)")
    func testPathDeniedScratch() {
        let tools = FileTools()
        #expect(tools.pathDenied("./.scratch/spec.md"))
    }

    @Test("pathDenied: /dev/stdin via pathDenied (new)")
    func testPathDeniedDevStdin() {
        let tools = FileTools()
        #expect(tools.pathDenied("/dev/stdin"))
    }

    @Test("pathDenied: /proc/self/environ via pathDenied (new)")
    func testPathDeniedProcEnviron() {
        let tools = FileTools()
        #expect(tools.pathDenied("/proc/self/environ"))
    }

    @Test("pathDenied: /tmp/legit.txt → allowed")
    func testPathDeniedTmpAllowed() {
        let tools = FileTools()
        #expect(!tools.pathDenied("/tmp/legit.txt"))
    }
}