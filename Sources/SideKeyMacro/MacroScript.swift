import Foundation

/// 一条可保存的宏脚本。
struct MacroScript: Identifiable, Codable, Equatable, Sendable {
    var id: UUID = UUID()
    var name: String
    var text: String
    var updatedAt: Date = Date()

    /// 列表/选择器里展示的名字（空名兜底）。
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? L10n.unnamedScript : trimmed
    }

    /// 用于脚本列表展示：名称 + 大致时长提示。
    var summary: String {
        guard let items = try? MacroDSL.parse(text) else { return L10n.parseFailed }
        return L10n.scriptSummary(count: items.count, duration: MacroDSL.durationText(of: items))
    }
}
