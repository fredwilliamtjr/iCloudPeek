#!/usr/bin/env swift
import Cocoa

let bundleID = "com.smartfull.icloudpeek"
let output = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "\(NSHomeDirectory())/Desktop/icloudpeek-capture.png"

let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
guard let app = apps.first else {
    FileHandle.standardError.write("iCloudPeek não está rodando\n".data(using: .utf8)!)
    exit(1)
}

let pid = app.processIdentifier
let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
    exit(2)
}

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
else {
    FileHandle.standardError.write("Nenhuma janela visível do iCloudPeek\n".data(using: .utf8)!)
    exit(3)
}

guard let image = CGWindowListCreateImage(
    .null,
    .optionIncludingWindow,
    windowID,
    [.bestResolution, .boundsIgnoreFraming]
) else {
    FileHandle.standardError.write("Falha ao capturar imagem da janela\n".data(using: .utf8)!)
    exit(4)
}

let rep = NSBitmapImageRep(cgImage: image)
guard let png = rep.representation(using: .png, properties: [:]) else {
    exit(5)
}

try? png.write(to: URL(fileURLWithPath: output))
print("Salvou: \(output) (\(image.width)x\(image.height))")
