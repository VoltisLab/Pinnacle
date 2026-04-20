import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    // Pin to a phone-ish aspect ratio by default so the compact UI reads
    // well on desktop, and set a sensible minimum so the layout doesn't
    // get crushed if the user shrinks the window.
    var windowFrame = self.frame
    windowFrame.size = NSSize(width: 480, height: 820)
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.minSize = NSSize(width: 420, height: 640)
    self.title = "Pinnacle"

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
