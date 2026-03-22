//
//  StatusBarViewModel.swift
//  TokenUsage
//
//  Created by Xueliang Zhu on 20/3/26.
//

import SwiftUI
import AppKit
import Combine

@MainActor
final class StatusBarViewModel: ObservableObject {
    @Published var title: String = "--"
    @Published var todayUsedQuota: Int = 0
    @Published var todayAddedQuota: Int = 0
    @Published var lastUpdated: String = "尚未更新"
    @Published var barImage: NSImage?
    @Published var tokenKey: String {
        didSet { UserDefaults.standard.set(tokenKey, forKey: "tokenKey") }
    }

    private var timer: Timer?

    init() {
        self.tokenKey = UserDefaults.standard.string(forKey: "tokenKey") ?? ""
        startPolling()
    }

    deinit {
        timer?.invalidate()
    }

    private func startPolling() {
        timer?.invalidate()

        Task {
            await fetch()
        }

        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task {
                await self.fetch()
            }
        }
    }

    func fetch() async {
        guard !tokenKey.isEmpty else {
            title = "请先设置 Token"
            return
        }

        guard let url = URL(string: "https://his.ppchat.vip/api/token-logs?token_key=\(tokenKey)&page=1&page_size=10") else {
            title = "URL错"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse,
                  200..<300 ~= http.statusCode else {
                title = "请求失败"
                return
            }

            let result = try JSONDecoder().decode(APIResponse.self, from: data)
            guard result.success else {
                title = "接口失败"
                return
            }

            let info = result.data.tokenInfo
            todayUsedQuota = info.todayUsedQuota
            todayAddedQuota = info.todayAddedQuota
            title = "已用 \(todayUsedQuota) / 新增 \(todayAddedQuota)"
            lastUpdated = "更新时间：\(Self.format(Date()))"

            updateBarImage()
        } catch {
            title = "请求异常"
            lastUpdated = error.localizedDescription
        }
    }

    private func updateBarImage() {
        let view = QuotaPieView(used: todayUsedQuota, total: todayAddedQuota)
        let renderer = ImageRenderer(content: view)

        renderer.scale = 2

        if let nsImage = renderer.nsImage {
            nsImage.isTemplate = false
            barImage = nsImage
        }
    }

    private static func format(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }
}

struct APIResponse: Decodable {
    let data: ResponseData
    let success: Bool
}

struct ResponseData: Decodable {
    let logs: [LogItem]
    let pagination: Pagination
    let tokenInfo: TokenInfo

    enum CodingKeys: String, CodingKey {
        case logs
        case pagination
        case tokenInfo = "token_info"
    }
}

struct LogItem: Decodable, Identifiable {
    let cacheCreationInputTokens: Int
    let cacheReadInputTokens: Int
    let completionTokens: Int
    let createdAt: Int
    let createdTime: String
    let modelName: String
    let promptTokens: Int
    let quota: Int

    var id: Int { createdAt }

    enum CodingKeys: String, CodingKey {
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
        case completionTokens = "completion_tokens"
        case createdAt = "created_at"
        case createdTime = "created_time"
        case modelName = "model_name"
        case promptTokens = "prompt_tokens"
        case quota
    }
}

struct Pagination: Decodable {
    let page: Int
    let pageSize: Int
    let total: Int
    let totalPages: Int

    enum CodingKeys: String, CodingKey {
        case page
        case pageSize = "page_size"
        case total
        case totalPages = "total_pages"
    }
}

struct TokenInfo: Decodable {
    let expiredTimeFormatted: String
    let expiry: Expiry
    let name: String
    let remainQuotaDisplay: Int
    let status: TokenStatus
    let todayAddedQuota: Int
    let todayBigTokenRequests: Int
    let todayOpusUsage: Int
    let todayUsageCount: Int
    let todayUsedQuota: Int

    enum CodingKeys: String, CodingKey {
        case expiredTimeFormatted = "expired_time_formatted"
        case expiry
        case name
        case remainQuotaDisplay = "remain_quota_display"
        case status
        case todayAddedQuota = "today_added_quota"
        case todayBigTokenRequests = "today_big_token_requests"
        case todayOpusUsage = "today_opus_usage"
        case todayUsageCount = "today_usage_count"
        case todayUsedQuota = "today_used_quota"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        expiredTimeFormatted = try container.decode(String.self, forKey: .expiredTimeFormatted)
        expiry = try container.decode(Expiry.self, forKey: .expiry)
        name = try container.decode(String.self, forKey: .name)
        remainQuotaDisplay = try container.decode(Int.self, forKey: .remainQuotaDisplay)
        status = try container.decode(TokenStatus.self, forKey: .status)
        todayAddedQuota = try container.decode(Int.self, forKey: .todayAddedQuota)
        todayUsageCount = try container.decode(Int.self, forKey: .todayUsageCount)
        todayUsedQuota = try container.decode(Int.self, forKey: .todayUsedQuota)

        if let intValue = try? container.decode(Int.self, forKey: .todayBigTokenRequests) {
            todayBigTokenRequests = intValue
        } else if let stringValue = try? container.decode(String.self, forKey: .todayBigTokenRequests),
                  let intValue = Int(stringValue) {
            todayBigTokenRequests = intValue
        } else {
            todayBigTokenRequests = 0
        }

        if let intValue = try? container.decode(Int.self, forKey: .todayOpusUsage) {
            todayOpusUsage = intValue
        } else if let stringValue = try? container.decode(String.self, forKey: .todayOpusUsage),
                  let intValue = Int(stringValue) {
            todayOpusUsage = intValue
        } else {
            todayOpusUsage = 0
        }
    }
}

struct Expiry: Decodable {
    let rawTimestamp: Int
    let status: String
    let time: String

    enum CodingKeys: String, CodingKey {
        case rawTimestamp = "raw_timestamp"
        case status
        case time
    }
}

struct TokenStatus: Decodable {
    let code: Int
    let text: String
    let type: String
}
