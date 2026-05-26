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
var showBar = true
var showRate = true

var barLength = 10
var rateBarLength = 5
var defaultContextWindowSize = 200_000
var warningThreshold = 50
var dangerThreshold = 80

// MARK: - Argument Parsing

let args = CommandLine.arguments
var argIndex = 1
while argIndex < args.count {
    switch args[argIndex] {
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
    case "--bar-length":
        argIndex += 1
        if argIndex < args.count, let v = Int(args[argIndex]) { barLength = v }
    case "--rate-bar-length":
        argIndex += 1
        if argIndex < args.count, let v = Int(args[argIndex]) { rateBarLength = v }
    case "--context-window-size":
        argIndex += 1
        if argIndex < args.count, let v = Int(args[argIndex]) { defaultContextWindowSize = v }
    case "--warning-threshold":
        argIndex += 1
        if argIndex < args.count, let v = Int(args[argIndex]) { warningThreshold = v }
    case "--danger-threshold":
        argIndex += 1
        if argIndex < args.count, let v = Int(args[argIndex]) { dangerThreshold = v }
    case "--help", "-h":
        print("""
            Usage: statusline [OPTIONS]

            Options (boolean):
              --show-project / --no-project     Show project path (default: on)
              --show-model / --no-model         Show model name (default: on)
              --show-branch / --no-branch       Show git branch (default: on)
              --show-dirty / --no-dirty         Show dirty mark (default: on)
              --show-usage / --no-usage         Show token usage (default: off)
              --show-cost / --no-cost           Show session cost (default: off)
              --show-bar / --no-bar             Show context bar graphic (default: on). Percent text is always shown.
              --show-rate / --no-rate           Show rate limit bar graphic (default: on). Label/time/percent text is always shown.

            Options (value):
              --bar-length <n>                  Context bar length (default: 10)
              --rate-bar-length <n>             Rate limit bar length (default: 5)
              --context-window-size <n>         Default context window size (default: 200000)
              --warning-threshold <n>           Warning threshold percent (default: 50)
              --danger-threshold <n>            Danger threshold percent (default: 80)
            """)
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

func runCommand(_ args: [String], suppressStderr: Bool = false) -> (output: String, status: Int32) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
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
    let formatter = DateFormatter()
    formatter.locale = Locale.current
    formatter.dateFormat = Calendar.current.isDateInToday(date) ? "H:mm" : "M/d"
    return formatter.string(from: date)
}

func formatTokens(_ value: Int) -> String {
    let v = Double(value)
    if v >= 1_000_000 { return String(format: "%.1fM", v / 1_000_000) }
    if v >= 1_000     { return String(format: "%.1fK", v / 1_000) }
    return "\(value)"
}

func renderBar(length: Int, ratio: Double) -> String {
    let filled = min(Int(ceil(Double(length) * ratio)), length)
    return String(repeating: "█", count: filled)
        + String(repeating: "░", count: length - filled)
}

// FIXME: OSC 8 ハイパーリンクが Claude Code のステータスラインで機能しない
// 対応されたら呼び出し側のリンク先 URL 生成と合わせて活用される
func osc8Link(url: String, text: String) -> String {
    "\u{001B}]8;;\(url)\u{0007}\(text)\u{001B}]8;;\u{0007}"
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

// MARK: - Input

let stdinData = FileHandle.standardInput.readDataToEndOfFile()
let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase
guard let input = try? decoder.decode(InputRoot.self, from: stdinData) else {
    print("Error: Invalid input")
    exit(1)
}

let cwd = FileManager.default.currentDirectoryPath

// MARK: - Build Segments

var mainParts: [String] = []

if showModel {
    let modelName = input.model?.displayName ?? "-"
    mainParts.append("\(cyan)\(modelName)\(reset)")
}

// contextWindow から使用量を取得
let limit: Int = input.contextWindow?.contextWindowSize ?? defaultContextWindowSize
let usageTokens: Int? = input.contextWindow?.currentUsage.map { u in
    (u.inputTokens ?? 0)
        + (u.cacheCreationInputTokens ?? 0)
        + (u.cacheReadInputTokens ?? 0)
        + (u.outputTokens ?? 0)
}

if limit > 0 {
    let usage = min(usageTokens ?? 0, limit)
    let ratio = Double(usage) / Double(limit)
    let percent = Int(ratio * 100)
    let barColor = colorForPercent(percent)
    if showBar {
        let bar = barColor + renderBar(length: barLength, ratio: ratio) + reset
        mainParts.append("\(bar) \(barColor)\(percent)%\(reset)")
    } else {
        mainParts.append("\(barColor)\(percent)%\(reset)")
    }
}

if let rateLimits = input.rateLimits {
    let entries: [(String, RateLimitWindow?)] = [("5h", rateLimits.fiveHour), ("7d", rateLimits.sevenDay)]
    let rateParts: [String] = entries.map { label, entry in
        guard let pct = entry?.usedPercentage else {
            return "\(gray)\(label):-%\(reset)"
        }
        let clampedPct = min(max(pct, 0), 100)
        let ratio = Double(clampedPct) / 100.0
        let color = colorForPercent(clampedPct)
        let prefix = entry?.resetsAt.map { "\(label)[\(formatResetTime($0))]" } ?? label
        if showRate {
            let bar = renderBar(length: rateBarLength, ratio: ratio)
            return "\(color)\(prefix):\(bar) \(clampedPct)%\(reset)"
        } else {
            return "\(color)\(prefix) \(clampedPct)%\(reset)"
        }
    }
    mainParts.append(rateParts.joined(separator: " \(gray)|\(reset) "))
}

if showUsage, let used = usageTokens {
    mainParts.append("\(formatTokens(used)) / \(formatTokens(limit))")
}

if showCost {
    let raw = input.cost?.totalCostUsd.map { String(format: "$%.5f", $0) } ?? "-"
    mainParts.append("\(purple)\(raw)\(reset)")
}

// MARK: - Branch & Project Path

var bottomParts: [String] = []

if showBranch || showDirty {
    let (branch, branchStatus) = runCommand(["git", "-C", cwd, "rev-parse", "--abbrev-ref", "HEAD"])

    if branchStatus == 0 && !branch.isEmpty {
        var dirtyMark = ""
        if showDirty {
            let (dirtyOutput, _) = runCommand(["git", "--no-optional-locks", "-C", cwd, "status", "--porcelain"])
            if !dirtyOutput.isEmpty { dirtyMark = "✱" }
        }

        if showBranch {
            var branchDisplay = branch
            let (remoteURL, remoteStatus) = runCommand(["git", "-C", cwd, "remote", "get-url", "origin"], suppressStderr: true)
            if remoteStatus == 0,
               let regex = try? NSRegularExpression(pattern: "github\\.com[:/]([^/]+/[^/]+?)(?:\\.git)?$"),
               let match = regex.firstMatch(in: remoteURL, range: NSRange(remoteURL.startIndex..., in: remoteURL)),
               let repoRange = Range(match.range(at: 1), in: remoteURL) {
                let url = "https://github.com/\(String(remoteURL[repoRange]))/tree/\(branch)"
                branchDisplay = osc8Link(url: url, text: branch)
            }
            let dirtyColor = dirtyMark.isEmpty ? "" : purple
            bottomParts.append("\(green)\(branchDisplay)\(dirtyColor)\(dirtyMark)\(reset)")
        }
    }
}

if showProject {
    let projectPath: String
    let (gitRoot, gitStatus) = runCommand(["git", "-C", cwd, "rev-parse", "--show-toplevel"], suppressStderr: true)
    if gitStatus == 0 && !gitRoot.isEmpty {
        let repoName = (gitRoot as NSString).lastPathComponent
        let relative = cwd == gitRoot ? "" : (cwd.hasPrefix(gitRoot + "/") ? String(cwd.dropFirst(gitRoot.count + 1)) : "")
        let relComponents = relative.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        if relComponents.isEmpty {
            projectPath = repoName
        } else if relComponents.count <= 2 {
            projectPath = "\(repoName)/\(relative)"
        } else {
            projectPath = "\(repoName)/.../\(relComponents.last!)"
        }
    } else {
        var p = cwd
        if let home = ProcessInfo.processInfo.environment["HOME"], p.hasPrefix(home) {
            p = "~" + String(p.dropFirst(home.count))
        }
        let components = p.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        if components.count > 4 {
            let root = components.first! == "~" ? "~" : ""
            p = root + "/.../" + components.suffix(3).joined(separator: "/")
        }
        projectPath = p
    }
    bottomParts.append(osc8Link(url: "file://\(cwd)", text: "\(gray)\(projectPath)\(reset)"))
}

// MARK: - Output

var output: [String] = mainParts
if !bottomParts.isEmpty {
    output.append(bottomParts.joined(separator: " \(gray)@\(reset) "))
}
print(output.joined(separator: " \(gray)|\(reset) "))
