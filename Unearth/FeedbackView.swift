//
//  FeedbackView.swift
//  Unearth
//
//  Created by Theo on 2026/6/11.
//

import SwiftUI
import PhotosUI

// MARK: - 反馈数据模型
struct FeedbackItem: Identifiable, Codable {
    let id: String
    let content: String
    let imageUrls: [String]?
    let videoUrl: String?
    let createdAt: String
    let status: FeedbackStatus
    let replies: [FeedbackReply]?

    var statusText: String {
        switch status {
        case .pending: return "待处理"
        case .processing: return "处理中"
        case .resolved: return "已解决"
        case .closed: return "已关闭"
        }
    }

    var statusColor: Color {
        switch status {
        case .pending: return .orange
        case .processing: return .blue
        case .resolved: return .green
        case .closed: return .gray
        }
    }
}

enum FeedbackStatus: String, Codable {
    case pending
    case processing
    case resolved
    case closed
}

struct FeedbackReply: Identifiable, Codable {
    let id: String
    let content: String
    let createdAt: String
    let isAdmin: Bool
}

// MARK: - 提交反馈页面
struct FeedbackSubmitView: View {
    @Binding var isPresented: Bool
    @State private var content: String = ""
    @State private var selectedImages: [UIImage] = []
    @State private var showImagePicker: Bool = false
    @State private var showPermissionAlert: Bool = false
    @State private var isSubmitting: Bool = false
    @State private var showSuccess: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    private let maxImages = 9
    private let maxContentLength = 500

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 文字输入
                    VStack(alignment: .leading, spacing: 8) {
                        Text("反馈内容")
                            .font(.headline)

                        ZStack(alignment: .topLeading) {
                            if content.isEmpty {
                                Text("请描述您遇到的问题或建议...")
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 8)
                            }

                            TextEditor(text: $content)
                                .frame(minHeight: 150)
                                .opacity(content.isEmpty ? 0.25 : 1)
                        }
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)

                        HStack {
                            Spacer()
                            Text("\(content.count)/\(maxContentLength)")
                                .font(.caption)
                                .foregroundColor(content.count > maxContentLength ? .red : .secondary)
                        }
                    }
                    .padding(.horizontal)

                    // 图片上传
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("添加图片")
                                .font(.headline)
                            Spacer()
                            Text("(\(selectedImages.count)/\(maxImages))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                            ForEach(selectedImages.indices, id: \.self) { index in
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: selectedImages[index])
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 100)
                                        .clipped()
                                        .cornerRadius(8)

                                    Button(action: {
                                        selectedImages.remove(at: index)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title3)
                                            .foregroundColor(.white)
                                            .shadow(radius: 2)
                                    }
                                    .padding(4)
                                }
                            }

                            if selectedImages.count < maxImages {
                                Button(action: {
                                    checkPhotoPermission()
                                }) {
                                    VStack {
                                        Image(systemName: "plus")
                                            .font(.title2)
                                            .foregroundColor(.gray)
                                        Text("添加图片")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .frame(height: 100)
                                    .frame(maxWidth: .infinity)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    // 提交按钮
                    Button(action: submitFeedback) {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text("提交反馈")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canSubmit ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!canSubmit || isSubmitting)
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("意见反馈")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("返回") {
                        isPresented = false
                    }
                }
            }
            .photosPicker(
                isPresented: $showImagePicker,
                selection: Binding<[PhotosPickerItem]>(
                    get: { [] },
                    set: { items in
                        loadImages(from: items)
                    }
                ),
                matching: .images
            )
            .alert("相册权限未开启", isPresented: $showPermissionAlert) {
                Button("去开启") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("需要获取相册权限才能选择图片")
            }
            .alert("提交成功", isPresented: $showSuccess) {
                Button("确定") {
                    isPresented = false
                }
            } message: {
                Text("感谢您的反馈，我们会尽快处理")
            }
            .alert("提交失败", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var canSubmit: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && content.count <= maxContentLength
    }

    private func checkPhotoPermission() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            showImagePicker = true
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        showImagePicker = true
                    } else {
                        showPermissionAlert = true
                    }
                }
            }
        case .denied, .restricted:
            showPermissionAlert = true
        @unknown default:
            break
        }
    }

    private func loadImages(from items: [PhotosPickerItem]) {
        for item in items {
            item.loadTransferable(type: Data.self) { result in
                DispatchQueue.main.async {
                    if case .success(let data) = result, let data = data, let image = UIImage(data: data) {
                        if selectedImages.count < maxImages {
                            selectedImages.append(image)
                        }
                    }
                }
            }
        }
    }

    private func submitFeedback() {
        guard canSubmit else { return }

        isSubmitting = true

        // 模拟提交
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isSubmitting = false
            showSuccess = true
        }
    }
}

// MARK: - 反馈列表页面
struct FeedbackListView: View {
    @State private var feedbacks: [FeedbackItem] = []
    @State private var isLoading: Bool = false
    @State private var expandedId: String? = nil
    @State private var showSubmitView: Bool = false

    var body: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }

            if feedbacks.isEmpty && !isLoading {
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("暂无反馈记录")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("提交反馈") {
                        showSubmitView = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
                .listRowSeparator(.hidden)
            }

            ForEach(feedbacks) { feedback in
                VStack(spacing: 0) {
                    // 反馈项
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if expandedId == feedback.id {
                                expandedId = nil
                            } else {
                                expandedId = feedback.id
                            }
                        }
                    }) {
                        FeedbackRow(feedback: feedback, isExpanded: expandedId == feedback.id)
                    }
                    .buttonStyle(PlainButtonStyle())

                    // 展开的时间轴
                    if expandedId == feedback.id {
                        FeedbackTimeline(feedback: feedback)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("我的反馈")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showSubmitView = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            loadFeedbacks()
        }
        .sheet(isPresented: $showSubmitView) {
            FeedbackSubmitView(isPresented: $showSubmitView)
        }
    }

    private func loadFeedbacks() {
        isLoading = true

        // 模拟数据
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            feedbacks = [
                FeedbackItem(
                    id: "fb_001",
                    content: "地图上显示的垃圾箱位置不准确，实际位置偏移了大约100米，希望能修正。",
                    imageUrls: nil,
                    videoUrl: nil,
                    createdAt: "2026-06-10 14:30",
                    status: .resolved,
                    replies: [
                        FeedbackReply(id: "r_001", content: "感谢您的反馈！我们已经核实并修正了该垃圾箱的位置信息。", createdAt: "2026-06-10 16:00", isAdmin: true)
                    ]
                ),
                FeedbackItem(
                    id: "fb_002",
                    content: "建议增加垃圾箱容量显示功能，方便用户了解垃圾箱是否已满。",
                    imageUrls: nil,
                    videoUrl: nil,
                    createdAt: "2026-06-09 10:15",
                    status: .processing,
                    replies: [
                        FeedbackReply(id: "r_002", content: "您好，感谢您的建议！我们已经将此需求加入开发计划中。", createdAt: "2026-06-09 14:30", isAdmin: true)
                    ]
                ),
                FeedbackItem(
                    id: "fb_003",
                    content: "上传图片时偶尔会失败，提示网络错误，但网络是正常的。",
                    imageUrls: nil,
                    videoUrl: nil,
                    createdAt: "2026-06-08 09:20",
                    status: .pending,
                    replies: nil
                )
            ]

            isLoading = false
        }
    }
}

// MARK: - 反馈行视图
struct FeedbackRow: View {
    let feedback: FeedbackItem
    let isExpanded: Bool

    var body: some View {
        HStack(spacing: 12) {
            // 状态图标
            ZStack {
                Circle()
                    .fill(feedback.statusColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                Image(systemName: statusIcon)
                    .font(.system(size: 18))
                    .foregroundColor(feedback.statusColor)
            }

            // 内容
            VStack(alignment: .leading, spacing: 4) {
                Text(feedback.content)
                    .font(.subheadline)
                    .lineLimit(2)
                    .foregroundColor(.primary)

                HStack {
                    Text(feedback.createdAt)
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Spacer()
                    Text(feedback.statusText)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(feedback.statusColor.opacity(0.2))
                        .foregroundColor(feedback.statusColor)
                        .cornerRadius(4)
                }
            }

            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }

    private var statusIcon: String {
        switch feedback.status {
        case .pending: return "clock"
        case .processing: return "gear"
        case .resolved: return "checkmark.circle"
        case .closed: return "xmark.circle"
        }
    }
}

// MARK: - 反馈时间轴
struct FeedbackTimeline: View {
    let feedback: FeedbackItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 16) {
                // 提交节点
                TimelineNode(
                    icon: "paperplane.fill",
                    color: .blue,
                    title: "提交反馈",
                    content: feedback.content,
                    time: feedback.createdAt,
                    isLast: feedback.replies == nil || feedback.replies!.isEmpty
                )

                // 回复节点
                if let replies = feedback.replies {
                    ForEach(replies) { reply in
                        TimelineNode(
                            icon: reply.isAdmin ? "person.fill.badge.shield.checkmark" : "person.fill",
                            color: reply.isAdmin ? .green : .gray,
                            title: reply.isAdmin ? "管理员回复" : "我的回复",
                            content: reply.content,
                            time: reply.createdAt,
                            isLast: reply.id == replies.last?.id
                        )
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6).opacity(0.5))
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - 时间轴节点
struct TimelineNode: View {
    let icon: String
    let color: Color
    let title: String
    let content: String
    let time: String
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 时间轴线和图标
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                }

                if !isLast {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2, height: 40)
                }
            }

            // 内容
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text(time)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }

                Text(content)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    NavigationView {
        FeedbackListView()
    }
}
