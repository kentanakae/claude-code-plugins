#!/usr/bin/env swift
//
// settings-helper.swift
// Claude Code Settings File Helper
//
// Copyright (c) 2025 KNT
//

import Foundation

// MARK: - Usage

func printUsage() -> Never {
    let usage = """
        Usage: settings-helper <subcommand> <path> [options]

        Subcommands:
          read <path>                          Read and output the JSON file
          has-statusline <path>                Check if statusLine key exists (exit 0=yes, 1=no)
          write-statusline <path> <command>    Set statusLine with the given command string
          remove-statusline <path>             Remove statusLine key from the file
        """
    fputs(usage + "\n", stderr)
    exit(1)
}

// MARK: - JSON Helpers

func readJSON(at path: String) -> [String: Any]? {
    guard let data = FileManager.default.contents(atPath: path),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return nil }
    return json
}

func writeJSON(_ dict: [String: Any], to path: String) {
    guard let data = try? JSONSerialization.data(
        withJSONObject: dict,
        options: [.prettyPrinted, .sortedKeys]
    ) else {
        fputs("Error: Failed to serialize JSON\n", stderr)
        exit(1)
    }
    var jsonString = String(data: data, encoding: .utf8) ?? "{}"
    if !jsonString.hasSuffix("\n") { jsonString += "\n" }

    // Create parent directory if needed
    let dir = (path as NSString).deletingLastPathComponent
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

    guard FileManager.default.createFile(atPath: path, contents: jsonString.data(using: .utf8)) else {
        fputs("Error: Failed to write file at \(path)\n", stderr)
        exit(1)
    }
}

// MARK: - Main

let args = CommandLine.arguments
guard args.count >= 3 else { printUsage() }

let subcommand = args[1]
let rawPath = args[2]
let path = NSString(string: rawPath).expandingTildeInPath

switch subcommand {
case "read":
    if let data = FileManager.default.contents(atPath: path),
       let text = String(data: data, encoding: .utf8) {
        print(text, terminator: "")
    } else {
        print("{}")
    }

case "has-statusline":
    guard let dict = readJSON(at: path), dict["statusLine"] != nil else {
        exit(1)
    }
    exit(0)

case "write-statusline":
    guard args.count >= 4 else {
        fputs("Error: write-statusline requires a command string\n", stderr)
        printUsage()
    }
    let command = args[3]
    var dict = readJSON(at: path) ?? [:]
    dict["statusLine"] = [
        "type": "command",
        "command": command,
        "padding": 0,
    ] as [String: Any]
    writeJSON(dict, to: path)

case "remove-statusline":
    guard var dict = readJSON(at: path) else {
        fputs("Error: Cannot read file at \(path)\n", stderr)
        exit(1)
    }
    dict.removeValue(forKey: "statusLine")
    writeJSON(dict, to: path)

default:
    fputs("Error: Unknown subcommand '\(subcommand)'\n", stderr)
    printUsage()
}
