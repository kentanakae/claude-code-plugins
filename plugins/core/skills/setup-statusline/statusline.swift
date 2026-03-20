#!/usr/bin/env swift
//
// statusline.swift
// Claude Code Custom Status Line
//
// Copyright (c) 2025 KNT
//

import Foundation

// MARK: - Default Configuration

var showProject = true
var showModel = true
var showBranch = true
var showDirty = true
var showUsage = false
var showCost = false

var showRate = true
var rateBarLength = 5

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
    case "--show-project": showProject = true
    case "--no-project":   showProject = false
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
    case "--help", "-h":
        let help = """
            Usage: statusline [OPTIONS]

            Options (boolean):
              --show-project / --no-project     Show project path (default: on)
              --show-model / --no-model         Show model name (default: on)
              --show-branch / --no-branch       Show git branch (default: on)
              --show-dirty / --no-dirty         Show dirty mark (default: on)
              --show-usage / --no-usage         Show token usage (default: off)
              --show-cost / --no-cost           Show session cost (default: off)
              --show-bar / --no-bar             Show context bar (default: on)
              --show-rate / --no-rate           Show rate limit (default: on)

            Options (value):
              --bar-length <n>                  Context bar length (default: 10)
              --context-window-size <n>         Default context window size (default: 200000)
              --warning-threshold <n>           Warning threshold percent (default: 50)
              --danger-threshold <n>            Danger threshold percent (default: 80)
              --rate-bar-length <n>            Rate limit bar length (default: 5)
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

func formatResetTime(_ timestamp: Int) -> String {
    let date = Date(timeIntervalSince1970: Double(timestamp))
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

struct RateLimitWindow: Decodable {
    let usedPercentage: Int?
    let resetsAt: Int?
}

struct RateLimits: Decodable {
    let fiveHour: RateLimitWindow?
    let sevenDay: RateLimitWindow?
}

struct InputRoot: Decodable {
    let model: Model?
    let cost: Cost?
    let contextWindow: ContextWindow?
    let rateLimits: RateLimits?
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
            // FIXME: OSC 8 ハイパーリンクが Claude Code のステータスラインで機能しない
            // 対応されたら GitHubリモートURLを取得してハイパーリンクを生成
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
if showRate, let rateLimits = input.rateLimits {
    let entries: [(String, RateLimitWindow?)] = [("5h", rateLimits.fiveHour), ("7d", rateLimits.sevenDay)]
    var rateParts: [String] = []
    for (label, entry) in entries {
        if let pct = entry?.usedPercentage {
            let clampedPct = min(max(pct, 0), 100)
            let ratio = Double(clampedPct) / 100.0
            let filledCount = min(Int(Double(rateBarLength) * ratio), rateBarLength)
            let emptyCount = rateBarLength - filledCount
            let bar = String(repeating: "█", count: filledCount)
                + String(repeating: "░", count: emptyCount)
            let color = colorForPercent(clampedPct)
            let resetPrefix: String
            if let timestamp = entry?.resetsAt {
                resetPrefix = "\(label)[\(formatResetTime(timestamp))]"
            } else {
                resetPrefix = label
            }
            rateParts.append("\(color)\(resetPrefix):\(bar) \(clampedPct)%\(reset)")
        } else {
            rateParts.append("\(gray)\(label):-%\(reset)")
        }
    }
    metricsParts.append(rateParts.joined(separator: " | "))
}

if showUsage, let used = usageTokens {
    metricsParts.append("\(formatTokens(used)) / \(formatTokens(limit))")
}

if showCost {
    let raw = input.cost?.totalCostUsd.map { String(format: "$%.5f", $0) } ?? "-"
    metricsParts.append("\(purple)\(raw)\(reset)")
}

var lines: [String] = []

if showProject {
    var projectPath = cwd
    if let home = ProcessInfo.processInfo.environment["HOME"], projectPath.hasPrefix(home) {
        projectPath = "~" + String(projectPath.dropFirst(home.count))
    }
    let components = projectPath.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
    if components.count > 4 {
        let root = components.first! == "~" ? "~" : ""
        projectPath = root + "/.../" + components.suffix(3).joined(separator: "/")
    }
    // FIXME: OSC 8 ハイパーリンクが Claude Code のステータスラインで機能しない
    // 対応されたら file:// フォールバックを削除する
    lines.append("\u{001B}]8;;file://\(cwd)\u{0007}\(gray)\(projectPath)\(reset)\u{001B}]8;;\u{0007}")
}

if !parts.isEmpty { lines.append(parts.joined(separator: " | ")) }
if !metricsParts.isEmpty { lines.append(metricsParts.joined(separator: " | ")) }
print(lines.joined(separator: "\n"))
