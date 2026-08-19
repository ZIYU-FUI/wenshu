//
//  CronjobTests.swift · Wenshu · v0.18 ticket 21 (cron)
//
//  单元测试 CronjobStore + Cronjob.parseSchedule + Cronjob.nextRun.
//

import Testing
import Foundation
@testable import WenshuApp

@Suite("Cronjob (hermes replica)")
struct CronjobTests {
    @Test("parseSchedule 5 字段 valid")
    func testParseScheduleValid() {
        #expect(CronjobStore.parseSchedule("0 * * * *") == true)
        #expect(CronjobStore.parseSchedule("0 0 * * 0") == true)
        #expect(CronjobStore.parseSchedule("*/5 * * * *") == true)
    }

    @Test("parseSchedule 无效")
    func testParseScheduleInvalid() {
        #expect(CronjobStore.parseSchedule("0 * * *") == false)  // 4 字段
        #expect(CronjobStore.parseSchedule("0 * * * * *") == false)  // 6 字段
        #expect(CronjobStore.parseSchedule("invalid") == false)
    }

    @Test("nextRun valid schedule 返 1 小时后")
    func testNextRunValid() {
        let now = Date()
        let next = CronjobStore.nextRun(schedule: "0 * * * *", after: now)
        #expect(next != nil)
        #expect(abs(next!.timeIntervalSince(now) - 3600) < 1.0)
    }

    @Test("nextRun invalid schedule 返 nil")
    func testNextRunInvalid() {
        #expect(CronjobStore.nextRun(schedule: "invalid") == nil)
    }

    @Test("store add + get + list")
    func testStoreAddGetList() async {
        let store = CronjobStore()
        let job = Cronjob(name: "auto-save", schedule: "*/5 * * * *", command: "wenshu-cli save")
        await store.add(job)
        let got = await store.get(id: job.id)
        #expect(got?.name == "auto-save")
        let all = await store.list()
        #expect(all.count == 1)
    }

    @Test("store setEnabled 改 enabled")
    func testStoreSetEnabled() async {
        let store = CronjobStore()
        let job = Cronjob(name: "test", schedule: "0 * * * *", command: "echo test")
        await store.add(job)
        await store.setEnabled(id: job.id, enabled: false)
        let got = await store.get(id: job.id)
        #expect(got?.enabled == false)
    }

    @Test("store delete 删 1 个")
    func testStoreDelete() async {
        let store = CronjobStore()
        let job = Cronjob(name: "test", schedule: "0 * * * *", command: "echo test")
        await store.add(job)
        await store.delete(id: job.id)
        let got = await store.get(id: job.id)
        #expect(got == nil)
    }
}