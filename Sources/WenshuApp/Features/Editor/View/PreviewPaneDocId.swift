//
//  PreviewPaneDocId.swift
//
//  Convenience stable-ID helper extracted from PreviewPane.swift
//  (= §6.6 god-class split: the cross-file `extension PreviewPane`
//  with the single `stableBookDocId` static func moved out of
//  the main file).
//
//  Why extracted (= §6.6 god-class split): the main `struct
//  PreviewPane: View` is 1397 LOC = 2.3x the 600-LOC cap. The
//  cross-file `extension PreviewPane` with the single
//  `stableBookDocId` nonisolated static func is a thin
//  convenience wrapper (= delegates to `BookDocIDFactory.make`).
//  Extracting it shrinks the main file by 8 LOC and creates a
//  clear home for any future ID-factory conveniences (= a
//  thin ID-factory adapter layer).
//
//  Access: `nonisolated static func stableBookDocId` = the
//  call site is `PreviewPane.stableBookDocId(...)` (= unchanged).
//

import Foundation

extension PreviewPane {
    /// Convenience: delegate to BookDocIDFactory.make. (= keeps the call site
    /// compact and centralises the hash algorithm choice.)
    nonisolated static func stableBookDocId(bookId: UUID, folderName: String, fileName: String) -> UUID {
        BookDocIDFactory.make(bookId: bookId, folderName: folderName, fileName: fileName)
    }
}
