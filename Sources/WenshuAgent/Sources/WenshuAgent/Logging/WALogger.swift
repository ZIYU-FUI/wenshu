//
//  WALogger.swift · Wenshu · WenshuAgent subsystem LOG (v3.1+ ticket: extract WenshuAgent)
//
//  Apple HIG canonical LOG surface for the WenshuAgent package.
//  Subsystem = "com.wenshu.agent" (= consistent with wenshu other future
//  subsystems like com.wenshu.ui, com.wenshu.data; the third-party
//  "com.wenshu.app" ubsystem is reserved for the SwiftData + UI layer).
//
//  Categories (= hermes style; = structured log by concern):
//    - agent      : public API entry/exit + WenshuAgent.shared chat()
//    - network    : HTTP/SSE transport (POST /v1/messages, bytes in/out, status code)
//    - keychain   : provider key save/load/delete
//    - model      : live /models discovery
//    - watchdog   : no-progress timeout detection
//    - stream     : per-event SSE byte-level parsing
//
//  Why this is a public symbol: future wenshu in-app developer tool /
//  diagnostic screen can read the same LOG surface (Console.app
//  filter = subsystem:com.wenshu.agent).
//
//  Created: 2026-10-16 (WenshuAgent P3.2)
//  Source: hermes `agent/log.py` + wenshu `Sources/WenshuApp/Features/Agent/Service/UserFacingError.swift`
//

import Foundation
import os

public enum WALogger {
    public static let subsystem = "com.wenshu.agent"

    public static let agent    = Logger(subsystem: subsystem, category: "agent")
    public static let network  = Logger(subsystem: subsystem, category: "network")
    public static let keychain = Logger(subsystem: subsystem, category: "keychain")
    public static let model    = Logger(subsystem: subsystem, category: "model")
    public static let watchdog = Logger(subsystem: subsystem, category: "watchdog")
    public static let stream   = Logger(subsystem: subsystem, category: "stream")
}
