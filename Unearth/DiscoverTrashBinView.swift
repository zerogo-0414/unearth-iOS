//
//  DiscoverTrashBinView.swift
//  Unearth
//
//  Created by Theo on 2026/6/9.
//

import SwiftUI
import MapKit

// MARK: - 发现垃圾箱页面
struct DiscoverTrashBinView: View {
    let capturedImage: UIImage
    @Binding var isPresented: Bool
    @State private var trashBinName: String = ""
    @State private var selectedTypes: Set<String> = []
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var showLocationPicker: Bool = false
    @State private var isSubmitting: Bool = false
    @State private var showSuccess: Bool = false
    @ObservedObject var loginManager = LoginManager.shared

    let trashBinTypes = [
        ("recyclable", "可回收", Color.green),
        ("general", "其他", Color.orange),
        ("hazardous", "有害", Color.red)
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 拍摄的照片
                    Image(uiImage: capturedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 250)
                        .cornerRadius(12)
                        .padding(.horizontal)

                    // 垃圾箱名称
                    VStack(alignment: .leading, spacing: 8) {
                        Text("垃圾箱名称")
                            .font(.headline)
                        TextField("请输入垃圾箱名称", text: $trashBinName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .padding(.horizontal)

                    // 类别选择（多选）
                    VStack(alignment: .leading, spacing: 8) {
                        Text("垃圾类别")
                            .font(.headline)

                        HStack(spacing: 12) {
                            ForEach(trashBinTypes, id: \.0) { type in
                                Button(action: {
                                    if selectedTypes.contains(type.0) {
                                        selectedTypes.remove(type.0)
                                    } else {
                                        selectedTypes.insert(type.0)
                                    }
                                }) {
                                    Text(type.1)
                                        .font(.subheadline)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(selectedTypes.contains(type.0) ? type.2 : Color(.systemGray5))
                                        .foregroundColor(selectedTypes.contains(type.0) ? .white : .primary)
                                        .cornerRadius(20)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    // 位置选择
                    VStack(alignment: .leading, spacing: 8) {
                        Text("位置")
                            .font(.headline)

                        Button(action: {
                            showLocationPicker = true
                        }) {
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.red)
                                if let location = selectedLocation {
                                    Text(String(format: "%.6f, %.6f", location.latitude, location.longitude))
                                        .font(.subheadline)
                                } else {
                                    Text("点击选择位置")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)

                    // 提交按钮
                    Button(action: submitDiscovery) {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text("提交发现")
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
            .navigationTitle("发现垃圾箱")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("返回") {
                        isPresented = false
                    }
                }
            }
            .sheet(isPresented: $showLocationPicker) {
                LocationPickerView(selectedLocation: $selectedLocation)
            }
            .alert("提交成功", isPresented: $showSuccess) {
                Button("确定") {
                    isPresented = false
                }
            } message: {
                Text("感谢您的发现！垃圾箱信息已提交审核。")
            }
        }
    }

    private var canSubmit: Bool {
        !trashBinName.isEmpty && !selectedTypes.isEmpty && selectedLocation != nil
    }

    private func submitDiscovery() {
        guard canSubmit else { return }

        isSubmitting = true

        // 模拟提交
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isSubmitting = false
            showSuccess = true
        }
    }
}

// MARK: - 位置选择器
struct LocationPickerView: View {
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @Environment(\.dismiss) var dismiss
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 32.024963, longitude: 118.912718),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )

    var body: some View {
        NavigationView {
            Map(coordinateRegion: $region, annotationItems: annotations) { item in
                MapPin(coordinate: item.coordinate, tint: .red)
            }
            .navigationTitle("选择位置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确定") {
                        selectedLocation = region.center
                        dismiss()
                    }
                }
            }
            .onAppear {
                // 使用当前用户位置作为默认中心
                if let userLocation = AMapLocationService.shared.currentLocation {
                    region.center = userLocation
                }
            }
        }
    }

    private var annotations: [MapAnnotationItem] {
        [MapAnnotationItem(coordinate: region.center)]
    }
}

struct MapAnnotationItem: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

#Preview {
    DiscoverTrashBinView(
        capturedImage: UIImage(systemName: "photo") ?? UIImage(),
        isPresented: .constant(true)
    )
}
