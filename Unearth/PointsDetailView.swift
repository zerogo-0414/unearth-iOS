//
//  PointsDetailView.swift
//  Unearth
//
//  Created by Theo on 2026/6/9.
//

import SwiftUI

// MARK: - 积分明细页面
struct PointsDetailView: View {
    @ObservedObject var pointsManager = PointsManager.shared
    @State private var selectedFilter: PointsFilter = .all

    enum PointsFilter: String, CaseIterable {
        case all = "全部"
        case earned = "获取"
        case spent = "扣除"
    }

    var filteredRecords: [PointsRecord] {
        switch selectedFilter {
        case .all:
            return pointsManager.records
        case .earned:
            return pointsManager.records.filter { $0.points > 0 }
        case .spent:
            return pointsManager.records.filter { $0.points < 0 }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 积分概览
            VStack(spacing: 12) {
                Text("当前积分")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("\(pointsManager.totalPoints)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.blue)

                // 统计信息
                HStack(spacing: 30) {
                    StatItem(title: "连续签到", value: "\(pointsManager.consecutiveDays)天", icon: "flame.fill", color: .orange)
                    StatItem(title: "签到积分", value: "\(pointsManager.getPointsByType(.signIn))", icon: "checkmark.circle.fill", color: .green)
                    StatItem(title: "互动积分", value: "\(interactionPoints)", icon: "heart.fill", color: .red)
                }
            }
            .padding()
            .background(Color(.systemBackground))

            // 筛选标签
            HStack(spacing: 8) {
                ForEach(PointsFilter.allCases, id: \.self) { filter in
                    Button(action: {
                        withAnimation {
                            selectedFilter = filter
                        }
                    }) {
                        Text(filter.rawValue)
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(selectedFilter == filter ? Color.blue : Color(.systemGray5))
                            .foregroundColor(selectedFilter == filter ? .white : .primary)
                            .cornerRadius(16)
                    }
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))

            Divider()

            // 积分记录列表
            if filteredRecords.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("暂无积分记录")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGray6))
            } else {
                List {
                    ForEach(filteredRecords) { record in
                        PointsRecordRow(record: record)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("积分明细")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var interactionPoints: Int {
        let likePoints = pointsManager.getPointsByType(.like) + pointsManager.getPointsByType(.beLiked)
        let favoritePoints = pointsManager.getPointsByType(.favorite) + pointsManager.getPointsByType(.beFavorited)
        return likePoints + favoritePoints
    }
}

// MARK: - 统计项
struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 积分记录行
struct PointsRecordRow: View {
    let record: PointsRecord

    var body: some View {
        HStack(spacing: 12) {
            // 图标
            ZStack {
                Circle()
                    .fill(record.points > 0 ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                    .frame(width: 40, height: 40)
                Image(systemName: record.type.iconName)
                    .font(.system(size: 18))
                    .foregroundColor(record.points > 0 ? .green : .red)
            }

            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(record.type.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(record.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Text(record.formattedDate)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            Spacer()

            // 积分
            Text(record.points > 0 ? "+\(record.points)" : "\(record.points)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(record.points > 0 ? .green : .red)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 签到弹窗
struct SignInAlertView: View {
    @Binding var isPresented: Bool
    @ObservedObject var pointsManager = PointsManager.shared
    @State private var showSuccess: Bool = false
    @State private var earnedPoints: Int = 0

    var body: some View {
        VStack(spacing: 20) {
            // 标题
            Text("每日签到")
                .font(.title2)
                .fontWeight(.bold)

            // 签到状态
            if pointsManager.isSignedInToday {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)

                    Text("今日已签到")
                        .font(.headline)

                    Text("连续签到 \(pointsManager.consecutiveDays) 天")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)

                    Text("签到可获得 10 积分")
                        .font(.headline)

                    if pointsManager.consecutiveDays > 0 {
                        Text("连续签到 \(pointsManager.consecutiveDays + 1) 天")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if (pointsManager.consecutiveDays + 1) % 7 == 0 {
                            Text("明天签到可获得连续签到奖励！")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
            }

            // 签到按钮
            if !pointsManager.isSignedInToday {
                Button(action: {
                    let success = pointsManager.signIn()
                    if success {
                        earnedPoints = 10
                        if pointsManager.consecutiveDays % 7 == 0 {
                            earnedPoints += pointsManager.consecutiveDays * 2
                        }
                        showSuccess = true
                    }
                }) {
                    Text("立即签到")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }

            // 关闭按钮
            Button(action: {
                isPresented = false
            }) {
                Text("关闭")
                    .foregroundColor(.secondary)
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 40)
        .alert("签到成功", isPresented: $showSuccess) {
            Button("确定") {
                isPresented = false
            }
        } message: {
            Text("获得 \(earnedPoints) 积分！")
        }
    }
}

#Preview {
    PointsDetailView()
}
