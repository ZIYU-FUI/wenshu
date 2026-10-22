// EditorChatEnvironment.swift · Wenshu
//
// The SwiftUI -> AppKit boundary for the editor column.
//
// `EditorChatNSController` hosts two `NSHostingController`s, and a
// SwiftUI `@Environment` chain does not cross into them. So the three
// objects the hosted SwiftUI views read (`AppState`, `BookStore`,
// `WenshuLibrary`) have to be re-injected with `.environment(...)`.
//
// Before this type existed, each of the three was carried as its own
// initializer parameter through `EditorChatSplitHost` ->
// `EditorChatNSController` -> `NSHostingController`: 3 objects x 3
// levels = 9 hand-carried values. This type carries them as ONE value,
// so the boundary carries one thing instead of three.
//
// It is a plain value, not an `EnvironmentKey`: the re-injection happens
// with `.environment(object)`, which needs no key at all. A key would be
// a second, parallel mechanism for the same job.
struct EditorChatEnvironment {
    let appState: AppState?
    let bookStore: BookStore?
    let library: WenshuLibrary?
}
