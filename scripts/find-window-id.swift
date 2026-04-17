#!/usr/bin/env swift
import Cocoa

let bundleID = "com.smartfull.icloudpeek"
let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
guard let app = apps.first else { exit(1) }
let pid = app.processIdentifier

guard let windowList = CGWindowListCopyWindowInfo(
    [.optionOnScreenOnly, .excludeDesktopElements],
    kCGNullWindowID
) as? [[String: Any]] else { exit(2) }

let appWindows = windowList.filter {
    ($0[kCGWindowOwnerPID as String] as? pid_t) == pid
}

func area(_ window: [String: Any]) -> CGFloat {
    guard let bounds = window[kCGWindowBounds as String] as? [String: Any],
          let w = bounds["Width"] as? CGFloat,
          let h = bounds["Height"] as? CGFloat
    else { return 0 }
    return w * h
}

guard let window = appWindows.max(by: { area($0) < area($1) }),
      let windowID = window[kCGWindowNumber as String] as? CGWindowID
else { exit(3) }

print(windowID)
