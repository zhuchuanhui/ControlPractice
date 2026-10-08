import Foundation

enum SceneLabel: String, CaseIterable, Codable {
    case story = "ストーリー"
    case buildup = "盛り上がり"
    case intimate = "親密な区間"
    case activity = "動きが大きい区間"
    case pause = "休止・場面転換"
    case unknown = "判定不能"
}

struct SceneAnalysis {
    static func estimate(motion: Double, changeRate: Double) -> SceneLabel {
        guard motion.isFinite, changeRate.isFinite else { return .unknown }
        // 静かな会話やストーリーのカットは「休止」ではなくストーリー扱いにする。
        // 休止はほぼ完全な静止が一定時間続く場合だけに限定する。
        if motion < 0.012 && changeRate < 0.008 { return .pause }
        if motion < 0.16 && changeRate < 0.35 { return .story }
        if motion < 0.32 { return .buildup }
        if motion < 0.65 { return .intimate }
        return .activity
    }
}
