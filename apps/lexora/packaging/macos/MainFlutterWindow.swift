import Cocoa
import Darwin
import FlutterMacOS
import SwiftUI

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    flutterViewController.backgroundColor = .clear
    RegisterGeneratedPlugins(registry: flutterViewController)

    title = "Lexora"
    titleVisibility = .hidden
    backgroundColor = .windowBackgroundColor
    isOpaque = false
    titlebarAppearsTransparent = true
    styleMask.insert(.fullSizeContentView)
    minSize = NSSize(width: 640, height: 540)
    isMovableByWindowBackground = false
    acceptsMouseMovedEvents = true

    let nativeToolbar = NSToolbar(identifier: "LexoraToolbar")
    nativeToolbar.displayMode = .iconOnly
    nativeToolbar.showsBaselineSeparator = false
    toolbar = nativeToolbar
    toolbarStyle = .unifiedCompact

    let channel = FlutterMethodChannel(
      name: "lexora/native-navigation",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    let navigation = LexoraNavigationModel(channel: channel)
    let host = NSHostingController(
      rootView: LexoraNativeShell(
        flutterViewController: flutterViewController,
        navigation: navigation
      )
    )
    let windowFrame = frame
    contentViewController = host
    setFrame(windowFrame, display: true)

    super.awakeFromNib()
  }
}

private final class LexoraNavigationModel: ObservableObject {
  @Published var selectedPage = 0
  @Published var customization: LexoraCustomization?
  private let channel: FlutterMethodChannel
  private var customizationResult: FlutterResult?

  init(channel: FlutterMethodChannel) {
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "isAvailable":
        result(true)
      case "pageChanged":
        if let page = call.arguments as? Int {
          DispatchQueue.main.async { self?.selectedPage = page }
        }
        result(nil)
      case "prepareMacInstaller":
        guard let path = call.arguments as? String else {
          result(FlutterError(code: "invalid_installer_path", message: "The installer path is missing.", details: nil))
          return
        }
        do {
          try Self.prepareMacInstaller(at: path)
          result(nil)
        } catch {
          result(FlutterError(code: "prepare_installer_failed", message: error.localizedDescription, details: path))
        }
      case "openMacInstaller":
        guard let path = call.arguments as? String else {
          result(FlutterError(code: "invalid_installer_path", message: "The installer path is missing.", details: nil))
          return
        }
        let opened = NSWorkspace.shared.open(URL(fileURLWithPath: path))
        result(opened)
      case "showCustomization":
        guard
          let arguments = call.arguments as? [String: Any],
          let customization = LexoraCustomization(arguments: arguments)
        else {
          result(
            FlutterError(
              code: "invalid_customization",
              message: "Lexora received invalid document settings.",
              details: nil
            )
          )
          return
        }
        DispatchQueue.main.async {
          self?.customizationResult = result
          self?.customization = customization
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func prepareMacInstaller(at path: String) throws {
    let timestamp = String(Int(Date().timeIntervalSince1970), radix: 16)
    let quarantine = "0081;\(timestamp);Lexora;"
    let data = Data(quarantine.utf8)
    let status = data.withUnsafeBytes { bytes in
      path.withCString { pathPointer in
        "com.apple.quarantine".withCString { namePointer in
          setxattr(pathPointer, namePointer, bytes.baseAddress, data.count, 0, 0)
        }
      }
    }
    guard status == 0 else {
      let code = errno
      let message = String(cString: strerror(code))
      throw NSError(
        domain: NSPOSIXErrorDomain,
        code: Int(code),
        userInfo: [NSLocalizedDescriptionKey: "The macOS installer could not be prepared: \(message)"]
      )
    }
  }

  func finishCustomization(_ value: LexoraCustomization?) {
    if let value {
      customizationResult?(value.dictionary)
    } else {
      customizationResult?(nil)
    }
    customizationResult = nil
    customization = nil
  }

  func select(_ page: Int) {
    guard page != selectedPage else { return }
    withAnimation(.timingCurve(0.23, 1, 0.32, 1, duration: 0.24)) {
      selectedPage = page
    }
    channel.invokeMethod("selectPage", arguments: page)
  }
}

private struct FlutterControllerContainer: NSViewControllerRepresentable {
  let controller: FlutterViewController

  func makeNSViewController(context: Context) -> FlutterViewController {
    controller
  }

  func updateNSViewController(
    _ nsViewController: FlutterViewController,
    context: Context
  ) {}
}

private struct LexoraNativeShell: View {
  let flutterViewController: FlutterViewController
  @StateObject private var navigation: LexoraNavigationModel
  @State private var prefersExpandedSidebar = true

  init(
    flutterViewController: FlutterViewController,
    navigation: LexoraNavigationModel
  ) {
    self.flutterViewController = flutterViewController
    _navigation = StateObject(wrappedValue: navigation)
  }

  var body: some View {
    GeometryReader { proxy in
      let canExpand = proxy.size.width >= 850
      let expanded = canExpand && prefersExpandedSidebar
      HStack(spacing: 0) {
        nativeSidebar(expanded: expanded, canExpand: canExpand)
          .frame(width: expanded ? 218 : 96)
          .animation(
            .timingCurve(0.77, 0, 0.175, 1, duration: 0.26),
            value: expanded
          )

        Divider().opacity(0.36)

        FlutterControllerContainer(controller: flutterViewController)
          .background(Color(nsColor: .windowBackgroundColor).opacity(0.72))
          .clipShape(Rectangle())
      }
      .background(LexoraBackdrop())
    }
    .ignoresSafeArea(edges: .top)
    .sheet(item: $navigation.customization) { customization in
      LexoraCustomizationSheet(
        initial: customization,
        onCancel: { navigation.finishCustomization(nil) },
        onSave: { navigation.finishCustomization($0) }
      )
    }
  }

  @ViewBuilder
  private func nativeSidebar(expanded: Bool, canExpand: Bool) -> some View {
    let content = VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 10) {
        Image(nsImage: NSApp.applicationIconImage)
          .resizable()
          .scaledToFit()
          .frame(width: 68, height: 68)
          .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        if expanded {
          Text("Lexora")
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .transition(.opacity.combined(with: .move(edge: .leading)))
        }
      }
      .frame(maxWidth: .infinity, alignment: expanded ? .leading : .center)
      .frame(height: 78)
      .padding(.horizontal, expanded ? 14 : 0)
      .padding(.top, 40)
      .padding(.bottom, 10)

      ForEach(Array(items.enumerated()), id: \.offset) { index, item in
        navigationButton(index: index, item: item, expanded: expanded)
      }

      Spacer(minLength: 12)

      if canExpand {
        Button {
          withAnimation(.timingCurve(0.77, 0, 0.175, 1, duration: 0.26)) {
            prefersExpandedSidebar.toggle()
          }
        } label: {
          HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
              .frame(width: 24)
            if expanded {
              Text(localized("收起边栏", "Collapse sidebar"))
            }
          }
          .frame(maxWidth: .infinity, alignment: expanded ? .leading : .center)
          .frame(height: 38)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 9)
        .help(expanded ? localized("收起边栏", "Collapse sidebar") : localized("展开边栏", "Expand sidebar"))
      }

      Text("3.1.0")
        .font(.caption2.monospacedDigit())
        .foregroundStyle(.tertiary)
        .frame(maxWidth: .infinity, alignment: expanded ? .leading : .center)
        .padding(.horizontal, expanded ? 15 : 0)
        .padding(.bottom, 14)
    }
    .padding(.horizontal, 7)
    .contentShape(Rectangle())

    if #available(macOS 26.0, *) {
      content
        .glassEffect(
          .clear.interactive(),
          in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .padding(5)
    } else {
      content
        .background(.ultraThinMaterial)
    }
  }

  @ViewBuilder
  private func navigationButton(
    index: Int,
    item: NavigationItem,
    expanded: Bool
  ) -> some View {
    let selected = navigation.selectedPage == index
    Button {
      navigation.select(index)
    } label: {
      HStack(spacing: 12) {
        Image(systemName: selected ? item.selectedSymbol : item.symbol)
          .font(.system(size: 16, weight: selected ? .semibold : .regular))
          .frame(width: 24)
        if expanded {
          Text(localized(item.zh, item.en))
            .font(.system(size: 13.5, weight: selected ? .semibold : .medium))
            .lineLimit(1)
            .transition(.opacity.combined(with: .move(edge: .leading)))
        }
      }
      .foregroundStyle(selected ? Color.accentColor : Color.secondary)
      .frame(maxWidth: .infinity, alignment: expanded ? .leading : .center)
      .frame(height: 42)
      .padding(.horizontal, expanded ? 12 : 0)
      .background {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(selected ? Color.accentColor.opacity(0.14) : Color.clear)
      }
      .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    .buttonStyle(.plain)
    .help(localized(item.zh, item.en))
  }

  private var items: [NavigationItem] {
    [
      NavigationItem(zh: "单词", en: "Words", symbol: "book.closed", selectedSymbol: "book.closed.fill"),
      NavigationItem(zh: "生成记录", en: "Generated", symbol: "doc.text", selectedSymbol: "doc.text.fill"),
      NavigationItem(zh: "历史", en: "History", symbol: "clock.arrow.circlepath", selectedSymbol: "clock.arrow.circlepath"),
      NavigationItem(zh: "设置", en: "Settings", symbol: "gearshape", selectedSymbol: "gearshape.fill"),
    ]
  }

  private func localized(_ zh: String, _ en: String) -> String {
    Locale.preferredLanguages.first?.lowercased().hasPrefix("zh") == true ? zh : en
  }
}

private struct LexoraCustomization: Identifiable {
  let id = UUID()
  var format: String
  var pageSize: String
  var preset: String
  var exampleAmount: String
  var smartReorder: Bool
  var word: Double
  var phonetic: Double
  var definition: Double
  var related: Double
  var example: Double
  var phrase: Double

  init?(arguments: [String: Any]) {
    guard
      let format = arguments["format"] as? String,
      let pageSize = arguments["pageSize"] as? String,
      let preset = arguments["preset"] as? String,
      let exampleAmount = arguments["exampleAmount"] as? String,
      let smartReorder = arguments["smartReorder"] as? Bool,
      let word = (arguments["word"] as? NSNumber)?.doubleValue,
      let phonetic = (arguments["phonetic"] as? NSNumber)?.doubleValue,
      let definition = (arguments["definition"] as? NSNumber)?.doubleValue,
      let related = (arguments["related"] as? NSNumber)?.doubleValue,
      let example = (arguments["example"] as? NSNumber)?.doubleValue,
      let phrase = (arguments["phrase"] as? NSNumber)?.doubleValue
    else { return nil }
    self.format = format
    self.pageSize = pageSize
    self.preset = preset
    self.exampleAmount = exampleAmount
    self.smartReorder = smartReorder
    self.word = word
    self.phonetic = phonetic
    self.definition = definition
    self.related = related
    self.example = example
    self.phrase = phrase
  }

  var dictionary: [String: Any] {
    [
      "format": format,
      "pageSize": pageSize,
      "preset": preset,
      "exampleAmount": exampleAmount,
      "smartReorder": smartReorder,
      "word": word,
      "phonetic": phonetic,
      "definition": definition,
      "related": related,
      "example": example,
      "phrase": phrase,
    ]
  }
}

private struct LexoraCustomizationSheet: View {
  @State private var draft: LexoraCustomization
  let onCancel: () -> Void
  let onSave: (LexoraCustomization) -> Void

  init(
    initial: LexoraCustomization,
    onCancel: @escaping () -> Void,
    onSave: @escaping (LexoraCustomization) -> Void
  ) {
    _draft = State(initialValue: initial)
    self.onCancel = onCancel
    self.onSave = onSave
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 12) {
        Image(systemName: "textformat.size")
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(Color.accentColor)
          .frame(width: 38, height: 38)
          .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        VStack(alignment: .leading, spacing: 2) {
          Text(localized("文档自定义", "Document customization"))
            .font(.title2.weight(.bold))
          Text(localized("调整下一份词汇书的格式、纸张与字号", "Format, paper, and typography for your next book"))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
      }
      .padding(20)

      Divider()

      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          settingGroup(localized("导出格式", "Export format")) {
            Picker("", selection: $draft.format) {
              Text("PDF").tag("pdf")
              Text("EPUB").tag("epub")
              Text("DOCX").tag("docx")
              Text(localized("分页图片", "Images")).tag("images")
              Text(localized("长图", "Long image")).tag("longImage")
            }
            .labelsHidden()
            .pickerStyle(.segmented)
          }

          HStack(alignment: .top, spacing: 14) {
            settingGroup(localized("纸张尺寸", "Paper size")) {
              Picker("", selection: $draft.pageSize) {
                Text("A4").tag("a4")
                Text("A5").tag("a5")
                Text("B5").tag("b5")
              }
              .labelsHidden()
              .pickerStyle(.segmented)
            }
            settingGroup(localized("字号预设", "Font preset")) {
              Picker("", selection: $draft.preset) {
                Text(localized("小", "Small")).tag("small")
                Text(localized("中", "Medium")).tag("medium")
                Text(localized("大", "Large")).tag("large")
              }
              .labelsHidden()
              .pickerStyle(.segmented)
              .onChange(of: draft.preset) { applyPreset($0) }
            }
          }

          HStack {
            Toggle(localized("智能调整顺序", "Smart reorder"), isOn: $draft.smartReorder)
            Spacer()
            Text(localized("只调整顺序，智能平衡长短词条以减少留白", "Balances entry lengths to reduce empty space"))
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          .padding(12)
          .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

          Text(localized("精细字号", "Fine typography"))
            .font(.headline)
          sliderCollection

          settingGroup(localized("例句", "Examples")) {
            Picker("", selection: $draft.exampleAmount) {
              Text(localized("不添加", "None")).tag("none")
              Text(localized("1 句", "1 sentence")).tag("one")
              Text(localized("2–3 句", "2–3 sentences")).tag("upToThree")
            }
            .labelsHidden()
            .pickerStyle(.segmented)
          }
        }
        .padding(20)
      }

      Divider()
      HStack {
        Spacer()
        Button(localized("取消", "Cancel"), action: onCancel)
          .keyboardShortcut(.cancelAction)
        Button(localized("保存调整", "Save changes")) { onSave(draft) }
          .keyboardShortcut(.defaultAction)
          .buttonStyle(.borderedProminent)
      }
      .padding(16)
    }
    .frame(width: 680, height: 700)
    .background(LexoraBackdrop())
  }

  @ViewBuilder
  private var sliderCollection: some View {
    let rows = VStack(spacing: 8) {
      sliderRow(localized("单词标题", "Word title"), value: binding(\.word), range: 6...30)
      sliderRow(localized("英美音标", "Phonetics"), value: binding(\.phonetic), range: 6...18)
      sliderRow(localized("中英文释义", "Definitions"), value: binding(\.definition), range: 6...18)
      sliderRow(localized("近义词与反义词", "Related words"), value: binding(\.related), range: 6...16)
      sliderRow(localized("双语例句", "Examples"), value: binding(\.example), range: 6...16)
      sliderRow(localized("短语与涵义", "Phrases"), value: binding(\.phrase), range: 6...16)
    }
    if #available(macOS 26.0, *) {
      GlassEffectContainer(spacing: 8) {
        rows
          .padding(10)
          .glassEffect(
            .clear.interactive(),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
          )
      }
    } else {
      rows
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
  }

  private func sliderRow(
    _ title: String,
    value: Binding<Double>,
    range: ClosedRange<Double>
  ) -> some View {
    HStack(spacing: 12) {
      Text(title)
        .font(.system(size: 12.5, weight: .medium))
        .frame(width: 116, alignment: .leading)
      Slider(value: value, in: range, step: 0.5)
      Text(String(format: "%.1f pt", value.wrappedValue))
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
        .frame(width: 54, alignment: .trailing)
    }
    .frame(height: 35)
  }

  private func binding(
    _ keyPath: WritableKeyPath<LexoraCustomization, Double>
  ) -> Binding<Double> {
    Binding(
      get: { draft[keyPath: keyPath] },
      set: { draft[keyPath: keyPath] = $0 }
    )
  }

  private func settingGroup<Content: View>(
    _ title: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title).font(.headline)
      content()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func applyPreset(_ preset: String) {
    switch preset {
    case "small":
      draft.word = 12; draft.phonetic = 7.4; draft.definition = 7.4
      draft.related = 6.4; draft.example = 6.4; draft.phrase = 6.4
    case "large":
      draft.word = 21.24; draft.phonetic = 12.78; draft.definition = 12.354
      draft.related = 10.224; draft.example = 10.224; draft.phrase = 10.224
    default:
      draft.word = 18; draft.phonetic = 9; draft.definition = 8.7
      draft.related = 7.2; draft.example = 7.2; draft.phrase = 7.2
    }
  }

  private func localized(_ zh: String, _ en: String) -> String {
    Locale.preferredLanguages.first?.lowercased().hasPrefix("zh") == true ? zh : en
  }
}

private struct NavigationItem {
  let zh: String
  let en: String
  let symbol: String
  let selectedSymbol: String
}

private struct LexoraBackdrop: View {
  var body: some View {
    ZStack {
      LegacyVisualEffect(material: .underWindowBackground)
        .ignoresSafeArea()
      LinearGradient(
        colors: [
          Color.accentColor.opacity(0.08),
          Color(nsColor: .windowBackgroundColor).opacity(0.58),
          Color.cyan.opacity(0.035),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()
    }
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
