import Testing
import Foundation
@testable import WenshuApp

@Suite("PlotThreadTracker")
struct PlotThreadToolsTests {
    private func fixture() throws -> (URL, UUID) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let book = UUID(); let shelf = root.appendingPathComponent("shelves/s/books/").appendingPathComponent(book.uuidString)
        try FileManager.default.createDirectory(at: shelf, withIntermediateDirectories: true)
        return (root, book)
    }
    @Test func testAddThread_persistsToBookConfig() async throws { let (r,b)=try fixture(); let t=PlotThreadTracker(projectRoot:r); try await t.add(PlotThread(bookId:b,title:"x")); #expect((try await t.list(bookId:b)).count == 1) }
    @Test func testUpdateThread_updatesLastReferencedIn() async throws { let (r,b)=try fixture(); let t=PlotThreadTracker(projectRoot:r); var x=PlotThread(bookId:b,title:"x"); try await t.add(x); let c=UUID(); x=PlotThread(id:x.id,bookId:b,title:"x",lastReferencedIn:c); try await t.update(x); #expect((try await t.list(bookId:b)).first?.lastReferencedIn == c) }
    @Test func testRemoveThread_removesFromBookConfig() async throws { let (r,b)=try fixture(); let t=PlotThreadTracker(projectRoot:r); let x=PlotThread(bookId:b,title:"x"); try await t.add(x); try await t.remove(id:x.id); #expect((try await t.list(bookId:b)).isEmpty) }
    @Test func testListThreads_filtersByStatus() async throws { let (r,b)=try fixture(); let t=PlotThreadTracker(projectRoot:r); try await t.add(PlotThread(bookId:b,title:"a",status:.open)); try await t.add(PlotThread(bookId:b,title:"d",status:.resolved)); #expect((try await t.list(bookId:b,status:.resolved)).count == 1) }
    @Test func testStaleThreads_returnsThreadsNotReferencedIn3Chapters() async throws { let (r,b)=try fixture(); let t=PlotThreadTracker(projectRoot:r); try await t.add(PlotThread(bookId:b,title:"old",introducedIn:UUID())); #expect((try await t.staleThreads(bookId:b)).count == 1) }
    @Test func testRecyclingMap_returnsThreadChapterMapping() async throws { let (r,b)=try fixture(); let t=PlotThreadTracker(projectRoot:r); let c=UUID(); let x=PlotThread(bookId:b,title:"x",introducedIn:c); try await t.add(x); #expect(try await t.recyclingMap(bookId:b)[c]?.contains(x.id) == true) }
}
