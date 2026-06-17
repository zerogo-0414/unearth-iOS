//
//  MyView.swift
//  Unearth
//
//  Created by Theo on 2026/6/9.
//

import SwiftUI

// MARK: - 我的页面
struct MyView: View {
    @ObservedObject var loginManager = LoginManager.shared
    @ObservedObject var pointsManager = PointsManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var showAvatarEditor: Bool = false
    @State private var showSignIn: Bool = false

    // 用户等级配置
    private var userLevel: UserLevelConfig {
        UserLevelConfig(likes: loginManager.likeCount, favorites: loginManager.favoriteCount)
    }

    // 头像刷新触发器
    @State private var avatarRefreshTrigger: Bool = false

    var body: some View {
        NavigationView {
            List {
                // 用户信息
                Section {
                    HStack(spacing: 16) {
                        // 像素头像
                        PixelAvatarView(gridSize: userLevel.gridSize, size: 60)
                            .id(avatarRefreshTrigger)  // 强制刷新
                            .onTapGesture {
                                showAvatarEditor = true
                            }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(loginManager.userName.isEmpty ? maskedPhone : loginManager.userName)
                                .font(.title3)
                                .fontWeight(.semibold)

                            Text("手机号: \(maskedPhone)")
                                .font(.caption)
                                .foregroundColor(.gray)

                            // 等级和宫格
                            HStack(spacing: 8) {
                                Text("Lv.\(userLevel.levelName)")
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.2))
                                    .foregroundColor(.blue)
                                    .cornerRadius(4)

                                Text("宫格: \(userLevel.gridSize)×\(userLevel.gridSize)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        // 编辑头像按钮
                        Button(action: {
                            showAvatarEditor = true
                        }) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // 积分和签到
                Section {
                    // 积分显示
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("我的积分")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(pointsManager.totalPoints)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }

                        Spacer()

                        // 签到按钮
                        Button(action: {
                            showSignIn = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: pointsManager.isSignedInToday ? "checkmark.circle.fill" : "star.circle.fill")
                                Text(pointsManager.isSignedInToday ? "已签到" : "签到")
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(pointsManager.isSignedInToday ? Color.gray : Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                        }
                        .disabled(pointsManager.isSignedInToday)

                        // 积分明细
                        NavigationLink(destination: PointsDetailView()) {
                            HStack(spacing: 6) {
                                Image(systemName: "list.bullet")
                                Text("明细")
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(20)
                        }
                    }

                    // 连续签到提示
                    if pointsManager.consecutiveDays > 0 {
                        HStack {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                            Text("连续签到 \(pointsManager.consecutiveDays) 天")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if (pointsManager.consecutiveDays + 1) % 7 == 0 {
                                Spacer()
                                Text("明天签到有额外奖励")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }

                // 功能列表
                Section("常用功能") {
                    NavigationLink(destination: MyTrashBinsView()) {
                        MenuRow(icon: "trash.fill", title: "我的垃圾箱", color: .green)
                    }

                    NavigationLink(destination: FavoriteListView()) {
                        MenuRow(icon: "heart.fill", title: "我的收藏", color: .red)
                    }

                    NavigationLink(destination: Text("历史记录")) {
                        MenuRow(icon: "clock.fill", title: "浏览历史", color: .orange)
                    }

                    NavigationLink(destination: Text("设置")) {
                        MenuRow(icon: "gearshape.fill", title: "设置", color: .gray)
                    }
                }

                // 其他
                Section("其他") {
                    NavigationLink(destination: FeedbackListView()) {
                        MenuRow(icon: "bubble.left.and.bubble.right.fill", title: "意见反馈", color: .blue)
                    }

                    NavigationLink(destination: Text("关于我们")) {
                        MenuRow(icon: "info.circle.fill", title: "关于我们", color: .gray)
                    }

                    NavigationLink(destination: Text("帮助与反馈")) {
                        MenuRow(icon: "questionmark.circle.fill", title: "帮助与反馈", color: .green)
                    }
                }

                // 注销账号和退出登录
                Section {
                    NavigationLink(destination: DeleteAccountView()) {
                        HStack {
                            Spacer()
                            Text("注销账号")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }

                    Button(action: {
                        loginManager.logout()
                        dismiss()
                    }) {
                        HStack {
                            Spacer()
                            Text("退出登录")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                    }
                }
            }
            .sheet(isPresented: $showAvatarEditor, onDismiss: {
                // 关闭编辑器后刷新头像
                avatarRefreshTrigger.toggle()
            }) {
                PixelAvatarEditorView(
                    isPresented: $showAvatarEditor,
                    gridSize: userLevel.gridSize
                )
            }
            .overlay {
                if showSignIn {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                            .onTapGesture {
                                showSignIn = false
                            }

                        SignInAlertView(isPresented: $showSignIn)
                    }
                }
            }
        }
    }

    // 手机号脱敏
    private var maskedPhone: String {
        let phone = loginManager.phoneNumber
        guard phone.count == 11 else { return phone }
        let start = phone.prefix(3)
        let end = phone.suffix(4)
        return "\(start)****\(end)"
    }
}

// MARK: - 菜单行
struct MenuRow: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 28, height: 28)

            Text(title)
                .font(.body)
        }
    }
}

#Preview {
    MyView()
}
