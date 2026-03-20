//
//  TokenUsageApp.swift
//  TokenUsage
//
//  Created by Xueliang Zhu on 20/3/26.
//

import SwiftUI

@main
struct TokenUsageApp: App {
    
    @StateObject private var vm = StatusBarViewModel()

    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 12) {
                if vm.tokenKey.isEmpty {
                    Text("请先设置 Token")
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 10) {
                        QuotaPieView(used: vm.todayUsedQuota, total: vm.todayAddedQuota)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("今日已用：\(vm.todayUsedQuota)")
                            Text("今日新增：\(vm.todayAddedQuota)")
                        }
                    }

                    Text(vm.lastUpdated)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                Button("设置 Token…") {
                    let alert = NSAlert()
                    alert.messageText = "设置 Token"
                    alert.informativeText = "请输入你的 token_key："
                    alert.addButton(withTitle: "确定")
                    alert.addButton(withTitle: "取消")

                    let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 260, height: 80))
                    scrollView.hasVerticalScroller = true
                    scrollView.autohidesScrollers = true

                    let textView = NSTextView(frame: scrollView.contentView.bounds)
                    textView.isEditable = true
                    textView.isRichText = false
                    textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
                    textView.autoresizingMask = [.width, .height]
                    textView.string = vm.tokenKey

                    scrollView.documentView = textView
                    alert.accessoryView = scrollView
                    alert.window.initialFirstResponder = textView

                    if alert.runModal() == .alertFirstButtonReturn {
                        let newToken = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !newToken.isEmpty {
                            vm.tokenKey = newToken
                            Task { await vm.fetch() }
                        }
                    }
                }

                Button("立即刷新") {
                    Task { await vm.fetch() }
                }

                Button("退出") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding()
            .frame(width: 240)
        } label: {
            if let image = vm.barImage {
                Image(nsImage: image)
            } else {
                Image(systemName: "chart.pie")
            }
        }
    }
}
