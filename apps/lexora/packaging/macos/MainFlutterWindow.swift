import Cocoa
import FlutterMacOS
import SwiftUI

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    flutterViewController.backgroundColor = .clear

    title = "Lexora"
    titleVisibility = .hidden
    backgroundColor = .windowBackgroundColor
    isOpaque = false
    titlebarAppearsTransparent = true
    styleMask.remove(.fullSizeContentView)
    minSize = NSSize(width: 640, height: 540)
    isMovableByWindowBackground = false
    acceptsMouseMovedEvents = true

    let nativeToolbar = NSToolbar(identifier: "LexoraToolbar")
    nativeToolbar.displayMode = .iconOnly
    nativeToolbar.showsBaselineSeparator = false
    toolbar = nativeToolbar
    toolbarStyle = .unifiedCompact

    let windowFrame = frame
    contentViewController = LexoraHostViewController(
      flutterViewController: flutterViewController
    )
    setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    super.awakeFromNib()
  }
}

/// Keeps Flutter as the frontmost AppKit child so every pointer event reaches
/// Flutter directly. SwiftUI is used only for the non-interactive glass
/// backdrop; it never participates in hit testing.
private final class LexoraHostViewController: NSViewController {
  private let flutterViewController: FlutterViewController

  init(flutterViewController: FlutterViewController) {
    self.flutterViewController = flutterViewController
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func loadView() {
    let rootView = NSView()
    rootView.wantsLayer = true

    // SwiftUI's `.allowsHitTesting(false)` only disables SwiftUI content. The
    // NSHostingView itself can still win AppKit hit testing, especially while
    // a Flutter modal route is visible. Use an AppKit-level pass-through view
    // as well so dialog, slider, and settings clicks always reach Flutter.
    let backdrop = NonHitTestingHostingView(rootView: LexoraBackdrop())
    backdrop.translatesAutoresizingMaskIntoConstraints = false
    rootView.addSubview(backdrop)

    addChild(flutterViewController)
    let flutterView = flutterViewController.view
    flutterView.translatesAutoresizingMaskIntoConstraints = false
    rootView.addSubview(flutterView, positioned: .above, relativeTo: backdrop)

    NSLayoutConstraint.activate([
      backdrop.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
      backdrop.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
      backdrop.topAnchor.constraint(equalTo: rootView.topAnchor),
      backdrop.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
      flutterView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
      flutterView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
      flutterView.topAnchor.constraint(equalTo: rootView.topAnchor),
      flutterView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
    ])

    view = rootView
  }

  override func viewDidAppear() {
    super.viewDidAppear()
    view.window?.makeFirstResponder(flutterViewController.view)
  }
}

private final class NonHitTestingHostingView<Content: View>: NSHostingView<Content> {
  override func hitTest(_ point: NSPoint) -> NSView? {
    nil
  }
}

private struct LexoraBackdrop: View {
  var body: some View {
    GeometryReader { geometry in
      let sidebarWidth: CGFloat = geometry.size.width >= 800
        ? 220
        : geometry.size.width >= 520 ? 76 : 0

      ZStack {
        LegacyVisualEffect(material: .underWindowBackground)
          .ignoresSafeArea()

        Color(nsColor: .windowBackgroundColor)
          .opacity(0.48)
          .ignoresSafeArea()

        if sidebarWidth > 0 {
          HStack(spacing: 0) {
            if #available(macOS 26.0, *) {
              Color.clear
                .frame(width: sidebarWidth)
                .glassEffect(.regular, in: Rectangle())
            } else {
              LegacyVisualEffect(material: .sidebar)
                .frame(width: sidebarWidth)
            }
            Rectangle()
              .fill(Color(nsColor: .separatorColor).opacity(0.38))
              .frame(width: 0.5)
            Spacer(minLength: 0)
          }
          .ignoresSafeArea()
        }
      }
    }
    .allowsHitTesting(false)
  }
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
