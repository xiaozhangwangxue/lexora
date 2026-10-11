import Flutter
import SwiftUI
import UIKit

/// iOS keeps Lexora's dictionary, learning, and document engines shared with
/// the other platforms, while the window chrome and navigation are native.
/// This gives iPhone and iPad real SwiftUI materials, accessibility behavior,
/// and Liquid Glass without duplicating the mature cross-platform features.
class SceneDelegate: FlutterSceneDelegate {
  private var navigationModel: LexoraIOSNavigationModel?

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    guard
      let window,
      let flutterController = window.rootViewController as? FlutterViewController
    else { return }

    flutterController.view.backgroundColor = .clear
    let channel = FlutterMethodChannel(
      name: "lexora/native-navigation",
      binaryMessenger: flutterController.binaryMessenger
    )
    let navigation = LexoraIOSNavigationModel(channel: channel)
    navigationModel = navigation

    let host = UIHostingController(
      rootView: LexoraIOSRootView(
        flutterController: flutterController,
        navigation: navigation
      )
    )
    host.view.backgroundColor = .clear
    window.rootViewController = host
    window.makeKeyAndVisible()
  }
}

private final class LexoraIOSNavigationModel: ObservableObject {
  @Published var selectedPage = 0
  @Published var navigationVisible = false

  private let channel: FlutterMethodChannel
  private var lastWordsTap = Date.distantPast

  init(channel: FlutterMethodChannel) {
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "isAvailable":
        result(true)
      case "pageChanged":
        if let page = call.arguments as? Int, (0...5).contains(page) {
          DispatchQueue.main.async { self?.selectedPage = page }
        }
        result(nil)
      case "navigationVisibility":
        if let visible = call.arguments as? Bool {
          DispatchQueue.main.async {
            withAnimation(.timingCurve(0.2, 0.82, 0.2, 1, duration: 0.20)) {
              self?.navigationVisible = visible
            }
          }
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func select(_ page: Int, reduceMotion: Bool) {
    let now = Date()
    if page == selectedPage {
      if page == 0, now.timeIntervalSince(lastWordsTap) <= 0.45 {
        channel.invokeMethod("resetSearch", arguments: nil)
        lastWordsTap = .distantPast
      } else if page == 0 {
        lastWordsTap = now
      }
      return
    }

    lastWordsTap = page == 0 ? now : .distantPast
    let update = { self.selectedPage = page }
    if reduceMotion {
      update()
    } else {
      withAnimation(.timingCurve(0.2, 0.82, 0.2, 1, duration: 0.18), update)
    }
    UISelectionFeedbackGenerator().selectionChanged()
    channel.invokeMethod("selectPage", arguments: page)
  }
}

private struct FlutterControllerContainer: UIViewControllerRepresentable {
  let controller: FlutterViewController

  func makeUIViewController(context: Context) -> FlutterViewController {
    controller
  }

  func updateUIViewController(
    _ uiViewController: FlutterViewController,
    context: Context
  ) {}
}

private struct LexoraIOSRootView: View {
  let flutterController: FlutterViewController

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @StateObject private var navigation: LexoraIOSNavigationModel

  init(
    flutterController: FlutterViewController,
    navigation: LexoraIOSNavigationModel
  ) {
    self.flutterController = flutterController
    _navigation = StateObject(wrappedValue: navigation)
  }

  var body: some View {
    Group {
      if horizontalSizeClass == .regular {
        HStack(spacing: 0) {
          if navigation.navigationVisible {
            nativeSidebar
              .frame(width: 218)
              .transition(.move(edge: .leading).combined(with: .opacity))
            Divider().opacity(0.45)
          }
          flutterContent
        }
      } else {
        flutterContent.safeAreaInset(edge: .bottom, spacing: 0) {
          if navigation.navigationVisible {
            nativeBottomBar
              .transition(.move(edge: .bottom).combined(with: .opacity))
          }
        }
      }
    }
    .background(Color(uiColor: .systemGroupedBackground))
  }

  private var flutterContent: some View {
    FlutterControllerContainer(controller: flutterController)
      .background(Color(uiColor: .systemGroupedBackground).opacity(0.72))
  }

  private var nativeSidebar: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 10) {
        Image(systemName: "character.book.closed.fill")
          .font(.system(size: 20, weight: .semibold))
          .foregroundStyle(Color.accentColor)
          .frame(width: 38, height: 38)
          .background(
            .thinMaterial,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
          )
        Text("Lexora")
          .font(.system(size: 20, weight: .semibold, design: .rounded))
      }
      .padding(.horizontal, 10)
      .padding(.top, 18)
      .padding(.bottom, 14)

      ForEach(Array(items.enumerated()), id: \.offset) { index, item in
        navigationButton(index: index, item: item, compact: false)
      }

      Spacer(minLength: 12)

      Text("Beta 5")
        .font(.caption2.monospacedDigit())
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    .padding(.horizontal, 10)
    .background(.ultraThinMaterial)
  }

  private var nativeBottomBar: some View {
    HStack(spacing: 3) {
      ForEach(Array(items.enumerated()), id: \.offset) { index, item in
        navigationButton(index: index, item: item, compact: true)
      }
    }
    .padding(.horizontal, 7)
    .padding(.vertical, 7)
    .modifier(LexoraGlassBarModifier())
    .padding(.horizontal, 8)
    .padding(.top, 4)
    .padding(.bottom, 2)
  }

  @ViewBuilder
  private func navigationButton(
    index: Int,
    item: LexoraIOSNavigationItem,
    compact: Bool
  ) -> some View {
    let selected = navigation.selectedPage == index
    Button {
      navigation.select(index, reduceMotion: reduceMotion)
    } label: {
      if compact {
        VStack(spacing: 3) {
          Image(systemName: selected ? item.selectedSymbol : item.symbol)
            .font(.system(size: 17, weight: selected ? .semibold : .regular))
          Text(localized(item.zh, item.en))
            .font(.system(size: 9.5, weight: selected ? .semibold : .medium))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .contentShape(Rectangle())
      } else {
        HStack(spacing: 12) {
          Image(systemName: selected ? item.selectedSymbol : item.symbol)
            .font(.system(size: 16, weight: selected ? .semibold : .regular))
            .frame(width: 24)
          Text(localized(item.zh, item.en))
            .font(.system(size: 14, weight: selected ? .semibold : .medium))
            .lineLimit(1)
          Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
      }
    }
    .buttonStyle(.plain)
    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
    .background {
      if selected {
        RoundedRectangle(cornerRadius: compact ? 16 : 13, style: .continuous)
          .fill(Color.accentColor.opacity(0.12))
          .transition(.opacity.combined(with: .scale(scale: 0.94)))
      }
    }
    .accessibilityLabel(localized(item.zh, item.en))
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  private var items: [LexoraIOSNavigationItem] {
    [
      .init(zh: "单词", en: "Words", symbol: "magnifyingglass", selectedSymbol: "text.magnifyingglass"),
      .init(zh: "词汇书", en: "Book", symbol: "book.closed", selectedSymbol: "book.closed.fill"),
      .init(zh: "生成", en: "Files", symbol: "doc.text", selectedSymbol: "doc.text.fill"),
      .init(zh: "历史", en: "History", symbol: "clock.arrow.circlepath", selectedSymbol: "clock.arrow.circlepath"),
      .init(zh: "学习", en: "Study", symbol: "graduationcap", selectedSymbol: "graduationcap.fill"),
      .init(zh: "设置", en: "Settings", symbol: "gearshape", selectedSymbol: "gearshape.fill"),
    ]
  }

  private func localized(_ zh: String, _ en: String) -> String {
    Locale.preferredLanguages.first?.lowercased().hasPrefix("zh") == true ? zh : en
  }
}

private struct LexoraGlassBarModifier: ViewModifier {
  @ViewBuilder
  func body(content: Content) -> some View {
    if #available(iOS 26.0, *) {
      content.glassEffect(
        .regular.interactive(),
        in: RoundedRectangle(cornerRadius: 25, style: .continuous)
      )
    } else {
      content
        .background(
          .ultraThinMaterial,
          in: RoundedRectangle(cornerRadius: 25, style: .continuous)
        )
        .overlay {
          RoundedRectangle(cornerRadius: 25, style: .continuous)
            .stroke(Color.primary.opacity(0.10), lineWidth: 0.5)
        }
        .shadow(color: Color.black.opacity(0.08), radius: 12, y: 5)
    }
  }
}

private struct LexoraIOSNavigationItem {
  let zh: String
  let en: String
  let symbol: String
  let selectedSymbol: String
}
