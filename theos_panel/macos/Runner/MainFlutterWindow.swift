import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    // Match the first Flutter splash surface so the native frame before the
    // engine paints is branded teal rather than the default black window.
    backgroundColor = NSColor(
      calibratedRed: 0.0,
      green: 0.494,
      blue: 0.510,
      alpha: 1.0
    )
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    // Assign the launch color to the *new* Flutter view. Setting it on the
    // previous contentView is ineffective because contentViewController
    // replaces that view, exposing AppKit's black default until Flutter draws.
    flutterViewController.view.wantsLayer = true
    flutterViewController.view.layer?.backgroundColor = backgroundColor?.cgColor
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()

    // The macOS runner can finish launching without making its Flutter
    // window key (notably when started from `flutter run`). Activate once
    // after the view hierarchy exists so text fields receive keyboard input;
    // do not repeat this on later focus changes or rebuilds.
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      NSApp.activate(ignoringOtherApps: true)
      self.makeKeyAndOrderFront(nil)
      // FlutterViewController's view is the responder that forwards native
      // key events to Flutter's text-input plugin. Using the window's
      // contentView wrapper can leave the window key while dropping typing.
      if let flutterView = self.contentViewController?.view {
        self.makeFirstResponder(flutterView)
      }
    }
  }
}
