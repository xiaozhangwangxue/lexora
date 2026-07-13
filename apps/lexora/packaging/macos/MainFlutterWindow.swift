import Cocoa
import FlutterMacOS
import SwiftUI

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    flutterViewController.backgroundColor = NSColor.clear

    backgroundColor = NSColor.clear
    isOpaque = false
    titlebarAppearsTransparent = true
    styleMask.insert(.fullSizeContentView)

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
      LinearGradient(
        colors: [
          Color(red: 0.91, green: 0.93, blue: 1.0),
          Color(red: 0.97, green: 0.95, blue: 1.0),
          Color(red: 0.91, green: 0.97, blue: 0.98),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()

      Circle()
        .fill(Color.indigo.opacity(0.16))
        .frame(width: 360, height: 360)
        .blur(radius: 70)
        .offset(x: -260, y: -210)

      Circle()
        .fill(Color.cyan.opacity(0.12))
        .frame(width: 420, height: 420)
        .blur(radius: 82)
        .offset(x: 330, y: 260)

      navigationMaterial
      FlutterSurface(controller: flutterViewController)
        .ignoresSafeArea()
    }
  }

  @ViewBuilder
  private var navigationMaterial: some View {
    HStack(spacing: 0) {
      if #available(macOS 26.0, *) {
        Color.clear
          .frame(width: 118)
          .glassEffect(
            .regular,
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
          )
          .padding(10)
      } else {
        LegacyVisualEffect()
          .frame(width: 118)
          .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
          .padding(10)
      }
      Spacer(minLength: 0)
    }
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
  func makeNSView(context: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    view.material = .sidebar
    view.blendingMode = .behindWindow
    view.state = .active
    return view
  }

  func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
