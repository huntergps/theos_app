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
    contentView?.wantsLayer = true
    contentView?.layer?.backgroundColor = backgroundColor?.cgColor
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
