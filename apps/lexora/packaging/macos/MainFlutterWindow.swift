import Cocoa
import FlutterMacOS
import SwiftUI

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    flutterViewController.backgroundColor = NSColor.clear

    title = "Lexora"
    titleVisibility = .hidden
    backgroundColor = NSColor.windowBackgroundColor
    isOpaque = false
    titlebarAppearsTransparent = true
    styleMask.remove(.fullSizeContentView)
    minSize = NSSize(width: 900, height: 620)
    // Flutter renders into a transparent view hosted by SwiftUI. Treating the
    // whole window background as draggable makes AppKit consume mouse events
    // before Flutter controls receive them. The native title bar remains the
    // correct drag region.
    isMovableByWindowBackground = false

    let nativeToolbar = NSToolbar(identifier: "LexoraToolbar")
    nativeToolbar.displayMode = .iconOnly
    nativeToolbar.showsBaselineSeparator = false
    toolbar = nativeToolbar
    toolbarStyle = .unifiedCompact

    let windowFrame = frame
    contentViewController = NSHostingController(
      rootView: LexoraWindowRoot(flutterViewController: flutterViewController)
    )
    setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    super.awakeFromNib()
  }
}

private struct LexoraWindowRoot: View {
  let flutterViewController: FlutterViewController

  var body: some View {
    ZStack {
      LegacyVisualEffect(material: .underWindowBackground)
        .ignoresSafeArea()

      Color(nsColor: .windowBackgroundColor)
        .opacity(0.46)
        .ignoresSafeArea()

      navigationMaterial
      FlutterSurface(controller: flutterViewController)
    }
  }

  @ViewBuilder
  private var navigationMaterial: some View {
    HStack(spacing: 0) {
      if #available(macOS 26.0, *) {
        Color.clear
          .frame(width: 220)
          .glassEffect(
            .regular,
            in: Rectangle()
          )
      } else {
        LegacyVisualEffect(material: .sidebar)
          .frame(width: 220)
      }
      Rectangle()
        .fill(Color(nsColor: .separatorColor).opacity(0.38))
        .frame(width: 0.5)
      Spacer(minLength: 0)
    }
    .ignoresSafeArea()
  }
}

private struct FlutterSurface: NSViewControllerRepresentable {
  let controller: FlutterViewController

  func makeNSViewController(context: Context) -> FlutterViewController {
    controller
  }

  func updateNSViewController(
    _ nsViewController: FlutterViewController,
    context: Context
  ) {}
}

private struct LegacyVisualEffect: NSViewRepresentable {
  let material: NSVisualEffectView.Material

  func makeNSView(context: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    view.material = material
    view.blendingMode = .behindWindow
    view.state = .active
    return view
  }

  func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
