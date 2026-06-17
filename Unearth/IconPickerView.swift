//
//  IconPickerView.swift
//  Unearth
//
//  Created by Theo on 2026/6/9.
//

import SwiftUI
import PhotosUI

// MARK: - 图标选择器
struct IconPickerView: View {
    let trashBin: TrashBinData
    @Binding var isPresented: Bool
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isloading: Bool = false

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // 当前图标预览
                VStack(spacing: 12) {
                    Text("当前图标")
                        .font(.headline)

                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 120, height: 120)

                        if let image = selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: trashBin.defaultIconName)
                                .font(.system(size: 50))
                                .foregroundColor(.blue)
                        }
                    }

                    Text(trashBin.name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)

                // 选择图片
                PhotosPicker(
                    selection: $selectedPhoto,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text("从相册选择图标")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 32)

                // 默认图标选择
                VStack(alignment: .leading, spacing: 12) {
                    Text("或选择默认图标")
                        .font(.headline)
                        .padding(.horizontal, 32)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(defaultIconNames, id: \.self) { iconName in
                            Button(action: {
                                // 选择默认图标
                            }) {
                                VStack {
                                    Image(systemName: iconName)
                                        .font(.system(size: 30))
                                        .foregroundColor(.blue)
                                        .frame(width: 60, height: 60)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(12)
                                    Text(iconShortName(iconName))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                }

                Spacer()

                // 保存按钮
                Button(action: saveIcon) {
                    HStack {
                        if isloading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text("保存图标")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedImage != nil ? Color.green : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(selectedImage == nil || isloading)
                .padding(.horizontal, 32)
                .padding(.bottom, 30)
            }
            .navigationTitle("更换图标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        isPresented = false
                    }
                }
            }
            .onChange(of: selectedPhoto) { _, newItem in
                loadPhoto(from: newItem)
            }
        }
    }

    // 加载选中的图片
    private func loadPhoto(from item: PhotosPickerItem?) {
        guard let item = item else { return }

        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    if let data = data, let image = UIImage(data: data) {
                        self.selectedImage = image
                    }
                case .failure(let error):
                    print("加载图片失败: \(error)")
                }
            }
        }
    }

    // 保存图标
    private func saveIcon() {
        guard let image = selectedImage,
              let imageData = image.jpegData(compressionQuality: 0.8) else { return }

        isloading = true

        // 获取当前登录用户名
        let currentUserName = LoginManager.shared.userName.isEmpty ? "匿名用户" : LoginManager.shared.userName

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            TrashBinDataManager.shared.saveCustomIcon(
                trashBinId: trashBin.id,
                imageData: imageData,
                updaterName: currentUserName,
                updateContent: "更换垃圾箱图标"
            )
            isloading = false
            isPresented = false
        }
    }

    // 默认图标列表
    private var defaultIconNames: [String] {
        [
            "trash.fill",
            "trash.circle.fill",
            "arrow.triangle.2.circlepath",
            "arrow.triangle.2.circlepath.circle.fill",
            "exclamationmark.triangle.fill",
            "exclamationmark.triangle",
            "leaf.fill",
            "leaf.circle.fill"
        ]
    }

    // 图标简短名称
    private func iconShortName(_ name: String) -> String {
        switch name {
        case "trash.fill": return "垃圾桶"
        case "trash.circle.fill": return "圆形垃圾桶"
        case "arrow.triangle.2.circlepath": return "回收"
        case "arrow.triangle.2.circlepath.circle.fill": return "圆形回收"
        case "exclamationmark.triangle.fill": return "警告"
        case "exclamationmark.triangle": return "警告线"
        case "leaf.fill": return "叶子"
        case "leaf.circle.fill": return "圆形叶子"
        default: return name
        }
    }
}

#Preview {
    IconPickerView(
        trashBin: defaultTrashBins[0],
        isPresented: .constant(true)
    )
}
