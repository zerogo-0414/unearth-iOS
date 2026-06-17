//
//  PixelAvatarEditor.swift
//  Unearth
//
//  Created by Theo on 2026/6/9.
//

import SwiftUI
import Photos

// MARK: - 像素颜色模型
struct PixelColor: Codable, Equatable {
    let r: Double
    let g: Double
    let b: Double
    let a: Double

    var color: Color { Color(uiColor: uiColor) }

    var uiColor: UIColor {
        UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a))
    }

    static var clear: PixelColor { PixelColor(r: 0, g: 0, b: 0, a: 0) }
    static var black: PixelColor { PixelColor(r: 0, g: 0, b: 0, a: 1) }
    static var white: PixelColor { PixelColor(r: 1, g: 1, b: 1, a: 1) }

    init(r: Double, g: Double, b: Double, a: Double = 1.0) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    init(color: Color) {
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.r = Double(r); self.g = Double(g); self.b = Double(b); self.a = Double(a)
    }
}

// MARK: - 头像数据模型
struct AvatarData: Codable {
    var gridSize: Int
    var pixels: [[PixelColor]]

    init(gridSize: Int) {
        self.gridSize = gridSize
        self.pixels = Array(repeating: Array(repeating: PixelColor.clear, count: gridSize), count: gridSize)
    }
}

// MARK: - 用户等级配置
struct UserLevelConfig {
    let likes: Int
    let favorites: Int

    var gridSize: Int {
        let totalPoints = likes + favorites
        if totalPoints >= 200 { return 48 }
        if totalPoints >= 100 { return 40 }
        if totalPoints >= 50 { return 32 }
        if totalPoints >= 20 { return 24 }
        return 6
    }

    var levelName: String {
        let totalPoints = likes + favorites
        if totalPoints >= 200 { return "大师" }
        if totalPoints >= 100 { return "专家" }
        if totalPoints >= 50 { return "进阶" }
        if totalPoints >= 20 { return "学徒" }
        return "新手"
    }
}

// MARK: - 预设颜色
let presetColors: [PixelColor] = [
    PixelColor(r: 0, g: 0, b: 0),
    PixelColor(r: 1, g: 1, b: 1),
    PixelColor(r: 0.5, g: 0.5, b: 0.5),
    PixelColor(r: 0.9, g: 0.1, b: 0.1),
    PixelColor(r: 0.8, g: 0.2, b: 0.2),
    PixelColor(r: 1.0, g: 0.4, b: 0.4),
    PixelColor(r: 1.0, g: 0.5, b: 0.0),
    PixelColor(r: 1.0, g: 0.7, b: 0.3),
    PixelColor(r: 1.0, g: 1.0, b: 0.0),
    PixelColor(r: 1.0, g: 0.9, b: 0.5),
    PixelColor(r: 0.0, g: 0.8, b: 0.0),
    PixelColor(r: 0.0, g: 0.5, b: 0.0),
    PixelColor(r: 0.5, g: 1.0, b: 0.5),
    PixelColor(r: 0.0, g: 0.0, b: 0.9),
    PixelColor(r: 0.0, g: 0.5, b: 1.0),
    PixelColor(r: 0.5, g: 0.8, b: 1.0),
    PixelColor(r: 0.5, g: 0.0, b: 0.5),
    PixelColor(r: 0.7, g: 0.3, b: 1.0),
    PixelColor(r: 0.5, g: 0.25, b: 0.0),
    PixelColor(r: 0.7, g: 0.5, b: 0.3),
    PixelColor(r: 1.0, g: 0.8, b: 0.6),
    PixelColor(r: 0.9, g: 0.7, b: 0.5),
]

// MARK: - 头像编辑器视图
struct PixelAvatarEditorView: View {
    @Binding var isPresented: Bool
    @State private var avatarData: AvatarData
    @State private var selectedColor: PixelColor = .black
    @State private var showClearConfirm: Bool = false
    @State private var showSaveAlbumConfirm: Bool = false
    @State private var showSaveAlbumSuccess: Bool = false
    @State private var showPermissionAlert: Bool = false

    // 缩放和拖动状态
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    @ObservedObject var loginManager = LoginManager.shared
    let gridSize: Int

    init(isPresented: Binding<Bool>, gridSize: Int = 6) {
        self._isPresented = isPresented
        self.gridSize = gridSize

        if let savedData = Self.loadProgress(gridSize: gridSize) {
            self._avatarData = State(initialValue: savedData)
        } else {
            self._avatarData = State(initialValue: AvatarData(gridSize: gridSize))
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                // 顶部信息
                HStack {
                    Text("宫格: \(gridSize)×\(gridSize)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("双指缩放 · 单指拖动")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)

                // 画布区域
                GeometryReader { geometry in
                    let baseCellSize: CGFloat = 40
                    let screenWidth = geometry.size.width
                    let initialScale = screenWidth / (baseCellSize * CGFloat(gridSize))
                    let cellSize = baseCellSize * scale * initialScale

                    ZStack {
                        Color(.systemGray6)

                        VStack(spacing: 0) {
                            ForEach(0..<gridSize, id: \.self) { row in
                                HStack(spacing: 0) {
                                    ForEach(0..<gridSize, id: \.self) { col in
                                        Rectangle()
                                            .fill(avatarData.pixels[row][col].color)
                                            .frame(width: cellSize, height: cellSize)
                                            .border(Color.gray.opacity(0.3), width: 0.5)
                                            .contentShape(Rectangle())
                                    }
                                }
                            }
                        }
                        .offset(x: offset.width, y: offset.height)
                        .gesture(
                            // 拖动和点击手势
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let dragDistance = sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2))

                                    // 如果拖动距离小于 10pt，视为点击填色
                                    if dragDistance < 10 {
                                        let currentCellSize = baseCellSize * scale * initialScale
                                        let canvasWidth = currentCellSize * CGFloat(gridSize)
                                        let canvasHeight = currentCellSize * CGFloat(gridSize)

                                        let x = value.location.x - offset.width
                                        let y = value.location.y - offset.height

                                        if x >= 0 && x < canvasWidth && y >= 0 && y < canvasHeight {
                                            let col = Int(x / currentCellSize)
                                            let row = Int(y / currentCellSize)

                                            if row >= 0 && row < gridSize && col >= 0 && col < gridSize {
                                                avatarData.pixels[row][col] = selectedColor
                                            }
                                        }
                                    }
                                }
                                .onEnded { value in
                                    let dragDistance = sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2))

                                    // 如果拖动距离大于等于 10pt，视为拖动画布
                                    if dragDistance >= 10 {
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                        lastOffset = offset
                                    } else {
                                        autoSave()
                                    }
                                }
                        )
                        .gesture(
                            // 双指缩放
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale = min(max(scale * delta, 0.2), 10.0)
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                }
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .border(Color.gray, width: 1)
                }

                // 颜色选择器
                VStack(spacing: 8) {
                    HStack {
                        Text("当前颜色:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Rectangle()
                            .fill(selectedColor.color)
                            .frame(width: 24, height: 24)
                            .border(Color.gray, width: 1)
                        Spacer()

                        // 居中画布按钮
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                offset = .zero
                                lastOffset = .zero
                                scale = 1.0
                                lastScale = 1.0
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.backward.and.arrow.down.forward")
                                Text("居中")
                                    .font(.caption)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(8)
                        }

                        // 橡皮擦按钮
                        Button(action: { selectedColor = .clear }) {
                            HStack(spacing: 4) {
                                Image(systemName: "eraser")
                                Text("橡皮擦")
                                    .font(.caption)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedColor == .clear ? Color.red.opacity(0.2) : Color(.systemGray5))
                            .foregroundColor(selectedColor == .clear ? .red : .primary)
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 6) {
                        ForEach(presetColors.indices, id: \.self) { index in
                            let color = presetColors[index]
                            Rectangle()
                                .fill(color.color)
                                .frame(height: 32)
                                .border(selectedColor == color ? Color.blue : Color.gray.opacity(0.3),
                                        width: selectedColor == color ? 2 : 1)
                                .cornerRadius(4)
                                .onTapGesture { selectedColor = color }
                        }
                    }
                    .padding(.horizontal)
                }

                // 底部按钮
                HStack(spacing: 12) {
                    Button(action: { showClearConfirm = true }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("清空")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.red)
                        .cornerRadius(10)
                    }

                    Button(action: saveAndClose) {
                        HStack {
                            Image(systemName: "checkmark")
                            Text("保存头像")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
            .navigationTitle("编辑头像")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("返回") {
                        autoSave()
                        isPresented = false
                    }
                }
            }
            .alert("确认清空", isPresented: $showClearConfirm) {
                Button("清空", role: .destructive) {
                    avatarData = AvatarData(gridSize: gridSize)
                    autoSave()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("确定要清空所有像素吗？")
            }
            .alert("保存成功", isPresented: $showSaveAlbumConfirm) {
                Button("保存到相册") { saveToAlbum() }
                Button("不用了", role: .cancel) { isPresented = false }
            } message: {
                Text("头像已保存，是否同时保存到相册？")
            }
            .alert("已保存到相册", isPresented: $showSaveAlbumSuccess) {
                Button("确定") { isPresented = false }
            }
            .alert("相册权限未开启", isPresented: $showPermissionAlert) {
                Button("去开启") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("取消", role: .cancel) { isPresented = false }
            } message: {
                Text("需要获取相册权限才能保存图片")
            }
        }
    }

    private func autoSave() {
        Self.saveProgress(avatarData, gridSize: gridSize)
    }

    private func saveAndClose() {
        Self.saveAvatar(avatarData)
        Self.saveProgress(avatarData, gridSize: gridSize)
        showSaveAlbumConfirm = true
    }

    private func saveToAlbum() {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            performSaveToAlbum()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        performSaveToAlbum()
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

    private func performSaveToAlbum() {
        guard let image = exportImage() else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        showSaveAlbumSuccess = true
    }

    private func exportImage() -> UIImage? {
        let cellSize: CGFloat = 20
        let imageSize = cellSize * CGFloat(gridSize)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: imageSize, height: imageSize))
        return renderer.image { context in
            context.cgContext.setFillColor(UIColor.white.cgColor)
            context.cgContext.fill(CGRect(x: 0, y: 0, width: imageSize, height: imageSize))
            for row in 0..<gridSize {
                for col in 0..<gridSize {
                    let color = avatarData.pixels[row][col]
                    if color.a > 0 {
                        let rect = CGRect(x: CGFloat(col) * cellSize, y: CGFloat(row) * cellSize, width: cellSize, height: cellSize)
                        context.cgContext.setFillColor(color.uiColor.cgColor)
                        context.cgContext.fill(rect)
                    }
                }
            }
        }
    }

    static func saveAvatar(_ data: AvatarData) {
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: "userAvatar")
        }
    }

    static func loadAvatar() -> AvatarData? {
        guard let data = UserDefaults.standard.data(forKey: "userAvatar"),
              let decoded = try? JSONDecoder().decode(AvatarData.self, from: data) else { return nil }
        return decoded
    }

    static func saveProgress(_ data: AvatarData, gridSize: Int) {
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: "avatarProgress_\(gridSize)")
        }
    }

    static func loadProgress(gridSize: Int) -> AvatarData? {
        guard let data = UserDefaults.standard.data(forKey: "avatarProgress_\(gridSize)"),
              let decoded = try? JSONDecoder().decode(AvatarData.self, from: data) else { return nil }
        return decoded
    }

    static func exportAvatar(gridSize: Int) -> UIImage? {
        guard let avatarData = loadAvatar(), avatarData.gridSize == gridSize else { return nil }
        let cellSize: CGFloat = 10
        let imageSize = cellSize * CGFloat(gridSize)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: imageSize, height: imageSize))
        return renderer.image { context in
            for row in 0..<gridSize {
                for col in 0..<gridSize {
                    let color = avatarData.pixels[row][col]
                    if color.a > 0 {
                        let rect = CGRect(x: CGFloat(col) * cellSize, y: CGFloat(row) * cellSize, width: cellSize, height: cellSize)
                        context.cgContext.setFillColor(color.uiColor.cgColor)
                        context.cgContext.fill(rect)
                    }
                }
            }
        }
    }
}

// MARK: - 头像显示视图
struct PixelAvatarView: View {
    let gridSize: Int
    let size: CGFloat
    @State private var avatarImage: UIImage?

    var body: some View {
        Group {
            if let image = avatarImage {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.gray)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .onAppear { avatarImage = PixelAvatarEditorView.exportAvatar(gridSize: gridSize) }
    }
}

// MARK: - LoginManager 扩展
extension LoginManager {
    var likeCount: Int {
        get { UserDefaults.standard.integer(forKey: "userLikeCount") }
        set { UserDefaults.standard.set(newValue, forKey: "userLikeCount") }
    }

    var favoriteCount: Int {
        get { UserDefaults.standard.integer(forKey: "userFavoriteCount") }
        set { UserDefaults.standard.set(newValue, forKey: "userFavoriteCount") }
    }
}

#Preview {
    PixelAvatarEditorView(isPresented: .constant(true), gridSize: 6)
}
