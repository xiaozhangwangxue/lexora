import AppKit
import Combine
import Foundation
import OSLog
import SwiftUI

private struct UnresolvedTerm: Codable, Identifiable {
    let term: String
    let kind: String?
    let gaps: [String]
    let status: String?
    let shard: Int?

    var id: String {
        "\(shard ?? -1)-\(term)-\(gaps.joined(separator: ","))"
    }
}

private struct Top20KShard: Codable, Identifiable {
    let shard: Int
    let total: Int
    let complete: Int
    let incomplete: Int
    let percent: Double
    let updatedAt: String?

    var id: Int { shard }
}

private struct Top20KProgress: Codable {
    let available: Bool?
    let ready: Bool?
    let total: Int
    let complete: Int
    let incomplete: Int
    let percent: Double
    let terms: [String: Int]?
    let missing: [String: Int]?
    let entryStatus: [String: Int]?
    let updatedAt: String?
    let unresolved: [UnresolvedTerm]?
    let shards: [Top20KShard]?
}

private struct ShardProgress: Codable, Identifiable {
    let shard: Int
    let finished: Int
    let total: Int
    let remaining: Int?
    let percent: Double?
    let entryStatus: [String: Int]?
    let providerStatus: [String: Int]?
    let providerAttempts: Int?
    let top20k: Top20KProgress?
    let updatedAt: String?

    var id: Int { shard }
}

private struct RemoteProgress: Codable {
    let finished: Int
    let total: Int
    let remaining: Int?
    let percent: Double?
    let entryStatus: [String: Int]?
    let providerStatus: [String: Int]?
    let providerAttempts: Int?
    let updatedAt: String?
    let oldestShardUpdatedAt: String?
    let shards: [ShardProgress]?
    let top20k: Top20KProgress?
}

private enum ProgressFetcher {
    static func fetchAll() async -> Result<RemoteProgress, Error> {
        guard let url = URL(string: "https://dict.12323456.xyz/v1/progress") else {
            return .failure(ProgressError.invalidAddress)
        }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard
                let response = response as? HTTPURLResponse,
                response.statusCode == 200,
                let value = try? JSONDecoder().decode(RemoteProgress.self, from: data),
                value.total > 0,
                value.finished >= 0,
                value.finished <= value.total
            else {
                return .failure(ProgressError.unavailable)
            }
            return .success(value)
        } catch {
            return .failure(error)
        }
    }

    private enum ProgressError: LocalizedError {
        case invalidAddress
        case unavailable

        var errorDescription: String? {
            switch self {
            case .invalidAddress:
                return "进度服务地址无效。"
            case .unavailable:
                return "暂时无法通过 Cloudflare 获取进度，正在保留上次结果。"
            }
        }
    }
}

@MainActor
private final class ProgressModel: ObservableObject {
    private let logger = Logger(
        subsystem: "xyz.12323456.lexora.progress",
        category: "progress"
    )
    @Published private(set) var snapshot: RemoteProgress
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastFetched: Date?
    @Published private(set) var errorMessage: String?

    private let defaults = UserDefaults.standard
    private var refreshLoop: Task<Void, Never>?

    init() {
        if
            let saved = defaults.data(forKey: "detailedSnapshot"),
            let decoded = try? JSONDecoder().decode(RemoteProgress.self, from: saved)
        {
            snapshot = decoded
        } else {
            let savedTotal = defaults.integer(forKey: "total")
            let savedFinished = defaults.integer(forKey: "finished")
            snapshot = RemoteProgress(
                finished: max(0, savedFinished),
                total: savedTotal > 0 ? savedTotal : 1_772_276,
                remaining: nil,
                percent: nil,
                entryStatus: nil,
                providerStatus: nil,
                providerAttempts: nil,
                updatedAt: nil,
                oldestShardUpdatedAt: nil,
                shards: nil,
                top20k: nil
            )
        }
        lastFetched = defaults.object(forKey: "lastFetched") as? Date
            ?? defaults.object(forKey: "lastUpdated") as? Date

        refreshLoop = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10 * 60 * 1_000_000_000)
                guard !Task.isCancelled else { break }
                self?.refresh()
            }
        }
        DispatchQueue.main.async { [weak self] in self?.refresh() }
    }

    deinit {
        refreshLoop?.cancel()
    }

    var fullFraction: Double {
        guard snapshot.total > 0 else { return 0 }
        return min(1, max(0, Double(snapshot.finished) / Double(snapshot.total)))
    }

    var fullPercentText: String {
        String(format: "%.2f%%", fullFraction * 100)
    }

    var top20KPercentText: String? {
        guard
            let top = snapshot.top20k,
            top.available == true,
            top.total > 0
        else { return nil }
        return String(format: "%.2f%%", Double(top.complete) / Double(top.total) * 100)
    }

    var menuTitle: String {
        if isRefreshing { return "Lexora …" }
        if let top20KPercentText {
            return "Lexora \(fullPercentText) · 20k \(top20KPercentText)"
        }
        return "Lexora \(fullPercentText)"
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        errorMessage = nil
        logger.info("Detailed progress refresh started")

        Task { [weak self] in
            let result = await ProgressFetcher.fetchAll()
            guard let self else { return }
            self.isRefreshing = false
            switch result {
            case let .success(value):
                self.snapshot = value
                self.lastFetched = Date()
                self.defaults.set(value.finished, forKey: "finished")
                self.defaults.set(value.total, forKey: "total")
                self.defaults.set(self.lastFetched, forKey: "lastFetched")
                if let data = try? JSONEncoder().encode(value) {
                    self.defaults.set(data, forKey: "detailedSnapshot")
                }
                self.logger.info(
                    "Detailed progress refresh completed: \(value.finished)/\(value.total)"
                )
            case let .failure(error):
                self.errorMessage = error.localizedDescription
                self.logger.error(
                    "Progress refresh failed: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }
}

private struct MetricRow: View {
    let title: String
    let value: String
    var color: Color = .secondary

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.system(.caption, design: .rounded).weight(.medium))
                .monospacedDigit()
                .foregroundStyle(color)
                .multilineTextAlignment(.trailing)
        }
        .font(.caption)
    }
}

private struct ProgressCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    init(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            content
        }
        .padding(14)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
    }
}

private struct ProgressPopover: View {
    @ObservedObject var model: ProgressModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    fullCollectionCard
                    top20KCard
                    serverCard

                    if let message = model.errorMessage {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(14)
            }

            Divider()
            footer
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .frame(width: 420, height: 650)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "book.closed.fill")
                .font(.title3)
                .foregroundStyle(.indigo)
                .frame(width: 30, height: 30)
                .background(
                    .indigo.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 9)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text("Lexora 采集进度")
                    .font(.headline)
                Text("全量采集与 20,000 极速词库质量")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if model.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private var fullCollectionCard: some View {
        let value = model.snapshot
        return ProgressCard(
            title: "全量词库",
            systemImage: "externaldrive.badge.icloud"
        ) {
            HStack(alignment: .firstTextBaseline) {
                Text(model.fullPercentText)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Spacer()
                Text("已处理")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: model.fullFraction)
                .tint(.indigo)
                .animation(
                    reduceMotion ? nil : .easeOut(duration: 0.18),
                    value: value.finished
                )
                .accessibilityLabel("全量词库处理进度")
                .accessibilityValue(model.fullPercentText)
            MetricRow(
                title: "数量",
                value: "\(formatted(value.finished)) / \(formatted(value.total))"
            )
            MetricRow(
                title: "剩余",
                value: formatted(
                    value.remaining ?? max(0, value.total - value.finished)
                )
            )
            if let statuses = value.entryStatus, !statuses.isEmpty {
                Divider()
                ForEach(statuses.keys.sorted(), id: \.self) { key in
                    MetricRow(
                        title: localizedStatus(key),
                        value: formatted(statuses[key] ?? 0)
                    )
                }
            }
            if let attempts = value.providerAttempts {
                MetricRow(title: "数据源请求尝试", value: formatted(attempts))
            }
            Text("“已处理”包含完整、部分完成和未找到；它不等于质量合格。")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var top20KCard: some View {
        ProgressCard(title: "20,000 极速词库", systemImage: "bolt.fill") {
            if
                let top = model.snapshot.top20k,
                top.available == true,
                top.total > 0
            {
                let percentText = String(
                    format: "%.2f%%",
                    Double(top.complete) / Double(top.total) * 100
                )
                HStack(alignment: .firstTextBaseline) {
                    Text(percentText)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    Spacer()
                    Label(
                        top.ready == true ? "可打包" : "尚未达标",
                        systemImage: top.ready == true
                            ? "checkmark.seal.fill"
                            : "hammer.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(
                        top.ready == true ? Color.green : Color.orange
                    )
                }
                ProgressView(
                    value: min(
                        1,
                        max(0, Double(top.complete) / Double(top.total))
                    )
                )
                .tint(top.ready == true ? .green : .orange)
                .accessibilityLabel("20,000 极速词库质量进度")
                .accessibilityValue(percentText)
                MetricRow(
                    title: "质量合格",
                    value: "\(formatted(top.complete)) / \(formatted(top.total))"
                )
                MetricRow(
                    title: "仍需补全",
                    value: formatted(top.incomplete),
                    color: top.incomplete == 0 ? .green : .orange
                )
                if let terms = top.terms {
                    MetricRow(
                        title: "构成",
                        value: "单词 \(formatted(terms["words"] ?? 0)) · 短语 \(formatted(terms["phrases"] ?? 0))"
                    )
                }
                if let missing = top.missing, !missing.isEmpty {
                    Divider()
                    Text("缺失字段（同一词条可能重复计数）")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    ForEach(missing.keys.sorted(), id: \.self) { key in
                        MetricRow(
                            title: localizedGap(key),
                            value: formatted(missing[key] ?? 0),
                            color: .orange
                        )
                    }
                }
                if let unresolved = top.unresolved, !unresolved.isEmpty {
                    Divider()
                    Text("待处理示例")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    ForEach(unresolved.prefix(6)) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Text(item.term)
                                .font(.caption.monospaced())
                                .lineLimit(1)
                            Spacer()
                            Text(
                                item.gaps.map(localizedGap)
                                    .joined(separator: "、")
                            )
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                        }
                    }
                }
                Text("只有 20,000 条全部通过释义、中文与普通单词音标/词性门禁后，才会生成正式极速包。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let top = model.snapshot.top20k, top.total > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Label("质量快照不完整", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text("目前只收到 \(top.shards?.count ?? 0) / 2 台服务器的质量快照；为避免误导，暂不计算 20,000 总进度。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    MetricRow(
                        title: "已收到的局部数据",
                        value: "\(formatted(top.complete)) / \(formatted(top.total))",
                        color: .orange
                    )
                }
            } else {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("两台服务器正在生成首份独立质量快照…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var serverCard: some View {
        ProgressCard(title: "服务器明细", systemImage: "server.rack") {
            if let shards = model.snapshot.shards, !shards.isEmpty {
                let sorted = shards.sorted { $0.shard < $1.shard }
                ForEach(Array(sorted.enumerated()), id: \.element.id) { index, shard in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("服务器 \(shard.shard + 1)")
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Text(
                                String(
                                    format: "%.2f%%",
                                    shardFraction(shard) * 100
                                )
                            )
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        }
                        ProgressView(value: shardFraction(shard))
                            .controlSize(.small)
                            .accessibilityLabel("服务器 \(shard.shard + 1) 全量词库处理进度")
                            .accessibilityValue(
                                String(
                                    format: "%.2f%%",
                                    shardFraction(shard) * 100
                                )
                            )
                        HStack {
                            Text(
                                "全量 \(formatted(shard.finished))/\(formatted(shard.total))"
                            )
                            Spacer()
                            if let top = shard.top20k, top.total > 0 {
                                Text(
                                    "20k \(formatted(top.complete))/\(formatted(top.total))"
                                )
                            }
                        }
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        if let date = displayDate(shard.updatedAt) {
                            Text("快照 \(date)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    if index < sorted.count - 1 {
                        Divider()
                    }
                }
            } else {
                Text("等待服务器明细快照")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var footer: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.isRefreshing ? "正在刷新…" : "最近读取 \(lastFetchText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let oldest = displayDate(model.snapshot.oldestShardUpdatedAt) {
                    Text("最旧服务器快照 \(oldest)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Button {
                model.refresh()
            } label: {
                Label("刷新", systemImage: "arrow.clockwise")
            }
            .disabled(model.isRefreshing)
            Button("退出") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }

    private var lastFetchText: String {
        guard let date = model.lastFetched else { return "尚未完成" }
        return date.formatted(date: .omitted, time: .shortened)
    }

    private func shardFraction(_ shard: ShardProgress) -> Double {
        guard shard.total > 0 else { return 0 }
        return min(1, max(0, Double(shard.finished) / Double(shard.total)))
    }

    private func formatted(_ value: Int) -> String {
        Self.integerFormatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private func localizedStatus(_ key: String) -> String {
        switch key {
        case "completed": return "完整完成"
        case "partial": return "部分完成"
        case "not_found": return "未找到"
        case "pending": return "等待处理"
        default: return key
        }
    }

    private func localizedGap(_ key: String) -> String {
        switch key {
        case "definition": return "英文释义"
        case "definition_zh": return "中文释义"
        case "phonetic": return "音标"
        case "pos": return "词性"
        default: return key
        }
    }

    private func displayDate(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let regular = ISO8601DateFormatter()
        regular.formatOptions = [.withInternetDateTime]
        guard let date = fractional.date(from: raw) ?? regular.date(from: raw) else {
            return nil
        }
        return date.formatted(date: .omitted, time: .shortened)
    }
}

@main
private struct LexoraProgressApp: App {
    @StateObject private var model = ProgressModel()

    var body: some Scene {
        MenuBarExtra {
            ProgressPopover(model: model)
        } label: {
            Label(model.menuTitle, systemImage: "book.closed.fill")
        }
        .menuBarExtraStyle(.window)
    }
}
