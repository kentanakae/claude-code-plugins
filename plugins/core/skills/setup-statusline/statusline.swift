#!/usr/bin/env swift
//
// statusline.swift
// Claude Code Custom Status Line
//
// Copyright (c) 2025 KNT
//

import Foundation

// MARK: - Default Configuration

var showModel = true
var showBranch = true
var showDirty = true
var showUsage = false
var showCost = false

var showRate = true
var showRateDetail = false
var rateBarLength = 5
var cacheTTL = 60

var showBar = true
var barLength = 10
var defaultContextWindowSize = 200_000
var warningThreshold = 50
var dangerThreshold = 80

// MARK: - Argument Parsing

let args = CommandLine.arguments
var argIndex = 1
while argIndex < args.count {
    switch args[argIndex] {
    // Boolean flags
    case "--show-model":   showModel = true
    case "--no-model":     showModel = false
    case "--show-branch":  showBranch = true
    case "--no-branch":    showBranch = false
    case "--show-dirty":   showDirty = true
    case "--no-dirty":     showDirty = false
    case "--show-usage":   showUsage = true
    case "--no-usage":     showUsage = false
    case "--show-cost":    showCost = true
    case "--no-cost":      showCost = false
    case "--show-bar":     showBar = true
    case "--no-bar":       showBar = false
    case "--show-rate":    showRate = true
    case "--no-rate":      showRate = false
    case "--rate-detail":    showRateDetail = true
    case "--no-rate-detail": showRateDetail = false
    // Value flags
    case "--bar-length":
        argIndex += 1
        if argIndex < args.count, let v = Int(args[argIndex]) { barLength = v }
    case "--context-window-size":
        argIndex += 1
        if argIndex < args.count, let v = Int(args[argIndex]) { defaultContextWindowSize = v }
    case "--warning-threshold":
        argIndex += 1
        if argIndex < args.count, let v = Int(args[argIndex]) { warningThreshold = v }
    case "--danger-threshold":
        argIndex += 1
        if argIndex < args.count, let v = Int(args[argIndex]) { dangerThreshold = v }
    case "--rate-bar-length":
        argIndex += 1
        if argIndex < args.count, let v = Int(args[argIndex]) { rateBarLength = v }
    case "--cache-ttl":
        argIndex += 1
        if argIndex < args.count, let v = Int(args[argIndex]) { cacheTTL = v }
    case "--help", "-h":
        let help = """
            Usage: statusline [OPTIONS]

            Options (boolean):
              --show-model / --no-model         Show model name (default: on)
              --show-branch / --no-branch       Show git branch (default: on)
              --show-dirty / --no-dirty         Show dirty mark (default: on)
              --show-usage / --no-usage         Show token usage (default: off)
              --show-cost / --no-cost           Show session cost (default: off)
              --show-bar / --no-bar             Show context bar (default: on)
              --show-rate / --no-rate           Show rate limit (default: on)
              --rate-detail / --no-rate-detail   Show per-model rate details (default: off)

            Options (value):
              --bar-length <n>                  Context bar length (default: 10)
              --context-window-size <n>         Default context window size (default: 200000)
              --warning-threshold <n>           Warning threshold percent (default: 50)
              --danger-threshold <n>            Danger threshold percent (default: 80)
              --rate-bar-length <n>            Rate limit bar length (default: 5)
              --cache-ttl <n>                  Cache TTL in seconds (default: 60)
            """
        print(help)
        exit(0)
    default:
        break
    }
    argIndex += 1
}

// MARK: - ANSI Colors

let reset = "\u{001B}[0m"
let cyan = "\u{001B}[96m"
let green = "\u{001B}[32m"
let yellow = "\u{001B}[33m"
let red = "\u{001B}[31m"
let purple = "\u{001B}[95m"
let gray = "\u{001B}[90m"

// MARK: - Helpers

func runCommand(executable: String = "/usr/bin/env", _ args: [String], suppressStderr: Bool = false) -> (output: String, status: Int32) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = args
    let pipe = Pipe()
    process.standardOutput = pipe
    if suppressStderr { process.standardError = FileHandle.nullDevice }
    try? process.run()
    process.waitUntilExit()
    let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return (output, process.terminationStatus)
}

func colorForPercent(_ pct: Int) -> String {
    switch pct {
    case 0..<warningThreshold: return green
    case warningThreshold..<dangerThreshold: return yellow
    default: return red
    }
}

// MARK: - Rate Limit Structs

struct RateLimitEntry: Decodable {
    let utilization: Double?
    let resetsAt: String?
}

struct UsageResponse: Decodable {
    let fiveHour: RateLimitEntry?
    let sevenDay: RateLimitEntry?
    let sevenDayOauthApps: RateLimitEntry?
    let sevenDayOpus: RateLimitEntry?
    let sevenDaySonnet: RateLimitEntry?
    let sevenDayCowork: RateLimitEntry?
}

// MARK: - Rate Limit Functions

func getAccessToken() -> String? {
    let (output, status) = runCommand(executable: "/usr/bin/security",
        ["find-generic-password", "-s", "Claude Code-credentials", "-w"], suppressStderr: true)
    guard status == 0, !output.isEmpty,
          let jsonData = output.data(using: .utf8),
          let root = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
          let oauth = root["claudeAiOauth"] as? [String: Any],
          let token = oauth["accessToken"] as? String else { return nil }
    return token
}

func formatResetTime(_ isoString: String) -> String? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    guard let date = formatter.date(from: isoString)
        ?? ISO8601DateFormatter().date(from: isoString) else { return nil }

    let calendar = Calendar.current
    let displayFormatter = DateFormatter()
    displayFormatter.locale = Locale.current

    if calendar.isDateInToday(date) {
        displayFormatter.dateFormat = "H:mm"
    } else {
        displayFormatter.dateFormat = "M/d"
    }

    return displayFormatter.string(from: date)
}

func fetchRateLimit(cacheTTL: Int) -> UsageResponse? {
    let cacheFile = "/tmp/claude-rate-limit-cache.json"
    let fm = FileManager.default

    // Check cache
    if let attrs = try? fm.attributesOfItem(atPath: cacheFile),
       let modDate = attrs[.modificationDate] as? Date,
       Date().timeIntervalSince(modDate) < Double(cacheTTL),
       let cacheData = fm.contents(atPath: cacheFile) {
        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        if let cached = try? dec.decode(UsageResponse.self, from: cacheData) {
            return cached
        }
    }

    // Fetch from API
    guard let token = getAccessToken(),
          let url = URL(string: "https://api.anthropic.com/api/oauth/usage") else { return nil }

    var request = URLRequest(url: url, timeoutInterval: 5)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

    let semaphore = DispatchSemaphore(value: 0)
    var result: UsageResponse?
    var responseData: Data?

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        defer { semaphore.signal() }
        guard error == nil, let data = data,
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else { return }
        responseData = data
        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        result = try? dec.decode(UsageResponse.self, from: data)
    }
    task.resume()
    _ = semaphore.wait(timeout: .now() + 6)

    // Write cache
    if let data = responseData {
        fm.createFile(atPath: cacheFile, contents: data)
    }

    return result
}

// MARK: - Data Structs

struct Model: Decodable {
    let displayName: String?
}

struct Cost: Decodable {
    let totalCostUsd: Double?
}

struct ContextWindow: Decodable {
    let contextWindowSize: Int?
    let currentUsage: CurrentUsage?
}

struct CurrentUsage: Decodable {
    let inputTokens: Int?
    let outputTokens: Int?
    let cacheCreationInputTokens: Int?
    let cacheReadInputTokens: Int?
}

struct InputRoot: Decodable {
    let model: Model?
    let cost: Cost?
    let contextWindow: ContextWindow?
}

func formatTokens(_ value: Int) -> String {
    let v = Double(value)
    if v >= 1_000_000 {
        return String(format: "%.1fM", v / 1_000_000)
    } else if v >= 1_000 {
        return String(format: "%.1fK", v / 1_000)
    } else {
        return "\(value)"
    }
}


let stdinData = FileHandle.standardInput.readDataToEndOfFile()
let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase
guard let input = try? decoder.decode(InputRoot.self, from: stdinData) else {
    print("Error: Invalid input")
    exit(1)
}

let cwd = FileManager.default.currentDirectoryPath

var parts: [String] = []
var metricsParts: [String] = []

if showModel {
    let modelName = input.model?.displayName ?? "-"
    parts.append("\(cyan)\(modelName)\(reset)")
}

if showBranch || showDirty {
    let (branch, branchStatus) = runCommand(["git", "-C", cwd, "rev-parse", "--abbrev-ref", "HEAD"])

    if branchStatus == 0 && !branch.isEmpty {
        var dirtyMark = ""
        if showDirty {
            let (dirtyOutput, _) = runCommand(["git", "--no-optional-locks", "-C", cwd, "status", "--porcelain"])
            if !dirtyOutput.isEmpty { dirtyMark = "✱" }
        }

        if showBranch {
            // GitHubリモートURLを取得してハイパーリンクを生成
            var githubBranchURL: String?
            let (remoteURL, remoteStatus) = runCommand(["git", "-C", cwd, "remote", "get-url", "origin"], suppressStderr: true)
            if remoteStatus == 0 {
                let pattern = "github\\.com[:/]([^/]+/[^/]+?)(?:\\.git)?$"
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: remoteURL, range: NSRange(remoteURL.startIndex..., in: remoteURL)),
                   let repoRange = Range(match.range(at: 1), in: remoteURL) {
                    githubBranchURL = "https://github.com/\(String(remoteURL[repoRange]))/tree/\(branch)"
                }
            }

            // OSC 8ハイパーリンク形式: ESC]8;;URL BEL text ESC]8;; BEL
            let branchDisplay: String
            if let url = githubBranchURL {
                branchDisplay = "\u{001B}]8;;\(url)\u{0007}\(branch)\u{001B}]8;;\u{0007}"
            } else {
                branchDisplay = branch
            }
            parts.append("\(green)\(branchDisplay)\(dirtyMark)\(reset)")
        }
    }
}

// contextWindow から使用量を取得
var usageTokens: Int?
var limit: Int = defaultContextWindowSize

if let cw = input.contextWindow {
    limit = cw.contextWindowSize ?? limit
    if let usage = cw.currentUsage {
        let tokens = (usage.inputTokens ?? 0)
            + (usage.cacheCreationInputTokens ?? 0)
            + (usage.cacheReadInputTokens ?? 0)
            + (usage.outputTokens ?? 0)
        usageTokens = tokens
    }
}

if showBar {
    let effectiveLimit = Int(Double(limit) * 0.95)

    let percent: Int
    if let used = usageTokens {
        let ratio = min(Double(used) / Double(effectiveLimit), 1.0)
        percent = Int(ratio * 100)
    } else {
        percent = 0
    }

    // バー全体を total にマッピング
    let usage = min(usageTokens ?? 0, limit)
    let usageBlocks = Int(round(Double(barLength) * Double(usage) / Double(limit)))
    let effectiveLimitPos = min(Int(Double(barLength) * Double(effectiveLimit) / Double(limit)), barLength - 1)

    let filled: Int
    let empty: Int
    let bufferFill: Int

    if usageBlocks <= effectiveLimitPos {
        // 使用量がバッファゾーン未到達
        filled = usageBlocks
        empty = effectiveLimitPos - usageBlocks
        bufferFill = barLength - effectiveLimitPos
    } else {
        // 使用量がバッファゾーンに食い込んでいる
        filled = usageBlocks
        empty = 0
        bufferFill = max(barLength - usageBlocks, 0)
    }

    let barColor = colorForPercent(percent)
    let bufferColor: String
    switch percent {
    case 0..<warningThreshold:   bufferColor = "\u{001B}[38;5;22m"
    case warningThreshold..<dangerThreshold: bufferColor = "\u{001B}[38;5;58m"
    default:                     bufferColor = "\u{001B}[38;5;52m"
    }

    let bar = barColor
        + String(repeating: "█", count: filled)
        + String(repeating: "░", count: empty)
        + bufferColor
        + String(repeating: "▓", count: bufferFill)
        + reset

    parts.append("\(bar) \(barColor)\(percent)%\(reset)")
}

// MARK: - Rate Limit Display
if showRate {
    if let usage = fetchRateLimit(cacheTTL: cacheTTL) {
        var entries: [(String, RateLimitEntry?)] = [("5h", usage.fiveHour), ("7d", usage.sevenDay)]
        if showRateDetail {
            let detailEntries: [(String, RateLimitEntry?)] = [
                ("7d-son", usage.sevenDaySonnet),
                ("7d-opus", usage.sevenDayOpus),
                ("7d-oauth", usage.sevenDayOauthApps),
                ("7d-cowk", usage.sevenDayCowork),
            ]
            entries.append(contentsOf: detailEntries)
        }
        var rateParts: [String] = []
        for (label, entry) in entries {
            if let util = entry?.utilization {
                let clampedUtil = min(max(util / 100.0, 0), 1.0)
                let pct = Int(clampedUtil * 100)
                let filledCount = min(Int(Double(rateBarLength) * clampedUtil), rateBarLength)
                let emptyCount = rateBarLength - filledCount
                let bar = String(repeating: "█", count: filledCount)
                    + String(repeating: "░", count: emptyCount)
                let color = colorForPercent(pct)
                let resetPrefix: String
                if let resetStr = entry?.resetsAt, let formatted = formatResetTime(resetStr) {
                    resetPrefix = "\(label)[\(formatted)]"
                } else {
                    resetPrefix = label
                }
                rateParts.append("\(color)\(resetPrefix):\(bar) \(pct)%\(reset)")
            } else if !showRateDetail {
                rateParts.append("\(gray)\(label):-%\(reset)")
            }
        }
        metricsParts.append(rateParts.joined(separator: " | "))
    } else {
        metricsParts.append("\(yellow)rate: login needed\(reset)")
    }
}

if showUsage, let used = usageTokens {
    metricsParts.append("\(formatTokens(used)) / \(formatTokens(limit))")
}

if showCost {
    let raw = input.cost?.totalCostUsd.map { String(format: "$%.5f", $0) } ?? "-"
    metricsParts.append("\(purple)\(raw)\(reset)")
}

var lines: [String] = []
if !parts.isEmpty { lines.append(parts.joined(separator: " | ")) }
if !metricsParts.isEmpty { lines.append(metricsParts.joined(separator: " | ")) }
print(lines.joined(separator: "\n"))
