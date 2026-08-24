//
//  NetworkModels.swift
//  DaysOff
//

import Foundation

// MARK: - Network Exhibition Model

struct NetworkExhibition: Codable, Identifiable {
    let id: UUID
    let userId: String
    let userName: String
    let name: String
    let introduction: String
    let startDate: String
    let endDate: String
    // 兼容字段：早期本地后端直接传图片二进制，远程后端恒为 null
    let firstPictureData: Data?
    let paintings: [Data]?
    let paintingIntroductions: [String]
    // 远程后端返回 OSS URL
    let firstPictureURL: String?
    let paintingURLs: [String]?
    let timestamp: Date

    // 共用的图片下载 session（ephemeral 不缓存到磁盘）
    private static let imageSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    /// 异步下载图片 URL 到 Data（失败返回 nil）
    static func loadData(from urlString: String?) async -> Data? {
        guard let urlString = urlString,
              let url = URL(string: urlString) else { return nil }
        do {
            let (data, response) = try await imageSession.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return data
        } catch {
            return nil
        }
    }

    /// 优先用本地 Data，没有则下载 OSS URL；返回首图 Data
    func resolveFirstPictureData() async -> Data? {
        if let data = firstPictureData { return data }
        return await Self.loadData(from: firstPictureURL)
    }

    /// 优先用本地 paintings，没有则下载 paintingURLs；返回所有画作 Data
    func resolvePaintingData() async -> [Data] {
        if let data = paintings, !data.isEmpty { return data }
        guard let urls = paintingURLs, !urls.isEmpty else { return [] }
        var result: [Data] = []
        for url in urls {
            if let data = await Self.loadData(from: url) {
                result.append(data)
            }
        }
        return result
    }
}

extension Array where Element == NetworkExhibition {
    /// 并行加载所有展览的首图，返回 ExhibitionRecord 列表
    func toExhibitionRecords() async -> [ExhibitionRecord] {
        var records: [ExhibitionRecord] = []
        for item in self {
            let firstPicture = await item.resolveFirstPictureData()
            records.append(
                ExhibitionRecord(
                    name: item.name,
                    introduction: item.introduction,
                    startDate: item.startDate,
                    endDate: item.endDate,
                    firstPictureData: firstPicture
                )
            )
        }
        return records
    }
}

// MARK: - Network Travel Idea Model

struct NetworkTravelIdea: Codable, Identifiable {
    let id: UUID
    let userId: String
    let userName: String
    let title: String
    let content: String
    let destination: String
    let landmark: String
    let date: String
    let startDate: Date?
    let endDate: Date?
    let timestamp: Date
}

struct SyncTravelIdeasRequest: Codable {
    let userId: String
    let userName: String
    let ideas: [TravelIdeaPayload]
}

struct TravelIdeaPayload: Codable {
    let id: UUID
    let title: String
    let content: String
    let destination: String
    let landmark: String
    let date: String
    let startDate: Date?
    let endDate: Date?
}
