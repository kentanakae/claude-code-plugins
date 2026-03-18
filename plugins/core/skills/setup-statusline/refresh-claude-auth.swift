#!/usr/bin/env swift
//
// refresh-claude-auth.swift
// Claude Code OAuth Token Refresh
//
// NOTE: Uses unofficial API endpoints discovered from Claude Code CLI internals.
// These may change without notice.
//

import Foundation

let clientId = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
let tokenURL = "https://platform.claude.com/v1/oauth/token"
let keychainService = "Claude Code-credentials"

// MARK: - Keychain

func getKeychainCreds() -> [String: Any]? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
    process.arguments = ["find-generic-password", "-s", keychainService, "-w"]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    try? process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { return nil }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
    return json
}

func setKeychainCreds(_ creds: [String: Any]) -> Bool {
    guard let data = try? JSONSerialization.data(withJSONObject: creds),
          let jsonStr = String(data: data, encoding: .utf8) else { return false }

    // Delete existing
    let del = Process()
    del.executableURL = URL(fileURLWithPath: "/usr/bin/security")
    del.arguments = ["delete-generic-password", "-s", keychainService]
    del.standardOutput = FileHandle.nullDevice
    del.standardError = FileHandle.nullDevice
    try? del.run()
    del.waitUntilExit()

    // Add new
    let add = Process()
    add.executableURL = URL(fileURLWithPath: "/usr/bin/security")
    add.arguments = ["add-generic-password", "-s", keychainService, "-a", "", "-w", jsonStr]
    add.standardOutput = FileHandle.nullDevice
    add.standardError = FileHandle.nullDevice
    try? add.run()
    add.waitUntilExit()
    return add.terminationStatus == 0
}

// MARK: - Main

guard let creds = getKeychainCreds(),
      let oauth = creds["claudeAiOauth"] as? [String: Any],
      let refreshToken = oauth["refreshToken"] as? String else {
    print("No credentials or refresh token found")
    exit(1)
}

// Check if refresh is needed (1 hour before expiry)
if let expiresAt = oauth["expiresAt"] as? String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let date = formatter.date(from: expiresAt) ?? ISO8601DateFormatter().date(from: expiresAt)
    if let exp = date {
        let remaining = exp.timeIntervalSinceNow
        if remaining > 3600 {
            let h = Int(remaining) / 3600
            let m = (Int(remaining) % 3600) / 60
            print("Token still valid for \(h)h \(m)m, skipping refresh")
            exit(0)
        }
    }
}

// Refresh token
guard let url = URL(string: tokenURL) else { exit(1) }
var request = URLRequest(url: url, timeoutInterval: 10)
request.httpMethod = "POST"
request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
let body = "grant_type=refresh_token&client_id=\(clientId)&refresh_token=\(refreshToken)"
request.httpBody = body.data(using: .utf8)

let semaphore = DispatchSemaphore(value: 0)
var responseData: Data?
var responseError: Error?

let task = URLSession.shared.dataTask(with: request) { data, response, error in
    defer { semaphore.signal() }
    if let error = error { responseError = error; return }
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
        responseError = NSError(domain: "", code: 1, userInfo: [NSLocalizedDescriptionKey: "HTTP error"])
        return
    }
    responseData = data
}
task.resume()
_ = semaphore.wait(timeout: .now() + 15)

guard let data = responseData,
      let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let newAccessToken = result["access_token"] as? String else {
    print("Refresh failed: \(responseError?.localizedDescription ?? "unknown error")")
    exit(1)
}

// Update credentials
var updatedOAuth = oauth
updatedOAuth["accessToken"] = newAccessToken
if let newRefresh = result["refresh_token"] as? String {
    updatedOAuth["refreshToken"] = newRefresh
}
if let expiresIn = result["expires_in"] as? Int {
    let exp = Date().addingTimeInterval(Double(expiresIn))
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    updatedOAuth["expiresAt"] = formatter.string(from: exp)
}

var updatedCreds = creds
updatedCreds["claudeAiOauth"] = updatedOAuth

if setKeychainCreds(updatedCreds) {
    print("Token refreshed successfully")
} else {
    print("Failed to update Keychain")
    exit(1)
}
