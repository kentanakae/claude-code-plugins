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

var autocompactBufferSize = 45_000

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
    // Value flags
    case "--autocompact-buffer-size":
        argIndex += 1
        if argIndex < args.count, let v = Int(args[argIndex]) { autocompactBufferSize = v }
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

            Options (value):
              --autocompact-buffer-size <n>     Autocompact buffer size (default: 45000)
              --bar-length <n>                  Context bar length (default: 10)
              --context-window-size <n>         Default context window size (default: 200000)
              --warning-threshold <n>           Warning threshold percent (default: 50)
              --danger-threshold <n>            Danger threshold percent (default: 80)
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
    let sessionID: String?
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

if showModel {
    let modelName = input.model?.displayName ?? "-"
    parts.append("\(cyan)\(modelName)\(reset)")
}

var branchText: String?
if showBranch || showDirty {
    let gitProcess = Process()
    gitProcess.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    gitProcess.arguments = [
        "git",
        "-C",
        cwd,
        "rev-parse",
        "--abbrev-ref",
        "HEAD",
    ]
    let gitPipe = Pipe()
    gitProcess.standardOutput = gitPipe
    try? gitProcess.run()
    gitProcess.waitUntilExit()
    let branch = String(
        data: gitPipe.fileHandleForReading.readDataToEndOfFile(),
        encoding: .utf8
    )?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    if gitProcess.terminationStatus == 0 && !branch.isEmpty {
        var dirtyMark = ""
        if showDirty {
            let dirtyProcess = Process()
            dirtyProcess.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            dirtyProcess.arguments = [
                "git",
                "--no-optional-locks",
                "-C",
                cwd,
                "status",
                "--porcelain",
            ]
            let dirtyPipe = Pipe()
            dirtyProcess.standardOutput = dirtyPipe
            try? dirtyProcess.run()
            dirtyProcess.waitUntilExit()
            let dirtyOutput = String(
                data: dirtyPipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            ) ?? ""
            if !dirtyOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                dirtyMark = "✱"
            }
        }

        // GitHubリモートURLを取得してハイパーリンクを生成
        var githubBranchURL: String?
        let remoteProcess = Process()
        remoteProcess.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        remoteProcess.arguments = ["git", "-C", cwd, "remote", "get-url", "origin"]
        let remotePipe = Pipe()
        remoteProcess.standardOutput = remotePipe
        remoteProcess.standardError = FileHandle.nullDevice
        try? remoteProcess.run()
        remoteProcess.waitUntilExit()

        if remoteProcess.terminationStatus == 0 {
            let remoteURL = String(
                data: remotePipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            )?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            // SSH形式: git@github.com:owner/repo.git
            // HTTPS形式: https://github.com/owner/repo.git
            let pattern = "github\\.com[:/]([^/]+/[^/]+?)(?:\\.git)?$"
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(
                   in: remoteURL,
                   range: NSRange(remoteURL.startIndex..., in: remoteURL)
               ),
               let repoRange = Range(match.range(at: 1), in: remoteURL)
            {
                let repoPath = String(remoteURL[repoRange])
                githubBranchURL = "https://github.com/\(repoPath)/tree/\(branch)"
            }
        }

        // OSC 8ハイパーリンク形式でブランチ名を生成
        // 形式: ESC]8;;URL BEL text ESC]8;; BEL
        let osc8Link = { (url: String, text: String) -> String in
            "\u{001B}]8;;\(url)\u{0007}\(text)\u{001B}]8;;\u{0007}"
        }
        if let url = githubBranchURL {
            branchText = "\(green)\(osc8Link(url, branch))\(dirtyMark)\(reset)"
        } else {
            branchText = "\(green)\(branch)\(dirtyMark)\(reset)"
        }

        if showBranch, let text = branchText {
            parts.append(text)
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
    let effectiveLimit = limit - autocompactBufferSize

    let percent: Int
    if let used = usageTokens {
        let ratio = min(Double(used) / Double(limit), 1.0)
        percent = Int(ratio * 100)
    } else {
        percent = 0
    }

    // バー全体を total にマッピング
    let usage = min(usageTokens ?? 0, limit)
    let usageBlocks = Int(round(Double(barLength) * Double(usage) / Double(limit)))
    let effectiveLimitPos = Int(round(Double(barLength) * Double(effectiveLimit) / Double(limit)))

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

    let barColor: String
    let bufferColor: String
    switch percent {
    case 0..<warningThreshold:
        barColor = green
        bufferColor = "\u{001B}[38;5;22m"
    case warningThreshold..<dangerThreshold:
        barColor = yellow
        bufferColor = "\u{001B}[38;5;58m"
    default:
        barColor = red
        bufferColor = "\u{001B}[38;5;52m"
    }

    let bar = barColor
        + String(repeating: "█", count: filled)
        + String(repeating: "░", count: empty)
        + bufferColor
        + String(repeating: "▓", count: bufferFill)
        + reset

    parts.append("\(bar) \(barColor)\(percent)%\(reset)")
}

if showUsage, let used = usageTokens {
    parts.append("\(formatTokens(used)) / \(formatTokens(limit))")
}

if showCost {
    let raw = input.cost?.totalCostUsd.map { String(format: "$%.5f", $0) } ?? "-"
    parts.append("\(purple)\(raw)\(reset)")
}

print(parts.joined(separator: " | "))
