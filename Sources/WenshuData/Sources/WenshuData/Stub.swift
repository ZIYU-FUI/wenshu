//
//  WenshuData/Stub.swift
//
//  v3.1 governance A1g.4.1: stub file present so the empty WenshuData
//  target compiles (= SPM rejects a product with zero sources). The
//  38 real source files (= 22 @Model + Container + ModelsSchema +
//  TypedID + LibraryMigrationState + 8 Repository + WSRepositoryContainer)
//  are moved here in A1g.4.2 (= the next commit). The stub is deleted
//  as part of A1g.4.2 (= no source code in the final layout should
//  depend on this file's existence).
//

// This empty enum is here purely so SPM does not reject the target as
// empty (= a product target with no source files is an error; = at least
// one .swift file is required). The actual data layer types live in
// the files moved to this directory in A1g.4.2.
enum WenshuDataStub {}
