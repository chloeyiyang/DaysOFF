import Foundation

/// 系统文字双语切换辅助函数
/// - 根据UserDefaults中的"app_language"返回对应语言文字
/// - "zh"(默认) → 返回中文；"en" → 返回英文
/// - 用户自己输入的中文内容不在系统文字范围内，保持原样
func L(_ zh: String, _ en: String) -> String {
    let lang = UserDefaults.standard.string(forKey: "app_language") ?? "zh"
    return lang == "en" ? en : zh
}

// MARK: - 心情词语翻译

/// 16 个心情词语的中英文对照
private let moodTranslations: [String: String] = [
    "压抑": "depressed",
    "忧虑": "anxious",
    "烦躁": "upset",
    "无聊": "bored",
    "不安": "uneasy",
    "接纳": "accepting",
    "轻松": "relaxed",
    "平静": "calm",
    "乐观": "optimistic",
    "喜悦": "joyful",
    "期待": "hopeful",
    "激动": "excited",
    "惊喜": "surprised",
    "满足": "content",
    "甜蜜": "sweet",
    "幸福": "happy",
    "心情": "mood"
]

/// 心情词语翻译：English 模式下将中文心情词转为英文，否则原样返回
func M(_ zh: String) -> String {
    let lang = UserDefaults.standard.string(forKey: "app_language") ?? "zh"
    guard lang == "en" else { return zh }
    return moodTranslations[zh] ?? zh
}

// MARK: - 作品类型翻译

/// 创作模块作品类型的中英文对照
private let artworkTypeTranslations: [String: String] = [
    "绘画": "Painting/Drawing",
    "书法": "Calligraphy",
    "手工": "Handicraft",
    "陶艺": "Pottery",
    "厨艺": "Culinary",
    "其他": "Others"
]

/// 作品类型翻译：English 模式下将中文类型转为英文，否则原样返回
func A(_ zh: String) -> String {
    let lang = UserDefaults.standard.string(forKey: "app_language") ?? "zh"
    guard lang == "en" else { return zh }
    return artworkTypeTranslations[zh] ?? zh
}

// MARK: - 日期格式翻译

/// 月份英文缩写
private let monthAbbreviations = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

/// 日期翻译：将 "M月d日" 格式翻译为 "MMM d"（如 "8月22日" → "Aug 22"）
/// 支持含时间后缀的字符串（如 "7月25日 19:30" → "Jul 25 19:30"）
/// 支持多日期（如 "8月22日 - 8月30日" → "Aug 22 - Aug 30"）
/// 存储保持中文格式，仅显示时翻译
func D(_ zh: String) -> String {
    let lang = UserDefaults.standard.string(forKey: "app_language") ?? "zh"
    guard lang == "en" else { return zh }
    let pattern = "(\\d{1,2})月(\\d{1,2})日"
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return zh }
    let nsString = NSString(string: zh)
    let range = NSRange(location: 0, length: nsString.length)
    var result = zh
    let matches = regex.matches(in: zh, range: range)
    // 从后往前替换，避免 range 偏移
    for match in matches.reversed() {
        guard match.numberOfRanges >= 3 else { continue }
        let monthStr = nsString.substring(with: match.range(at: 1))
        let dayStr = nsString.substring(with: match.range(at: 2))
        if let month = Int(monthStr), month >= 1 && month <= 12 {
            let replacement = "\(monthAbbreviations[month - 1]) \(dayStr)"
            if let swiftRange = Range(match.range, in: result) {
                result.replaceSubrange(swiftRange, with: replacement)
            }
        }
    }
    return result
}
