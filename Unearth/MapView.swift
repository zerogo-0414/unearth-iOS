//
//  MapView.swift
//  Unearth
//
//  Created by Theo on 2026/5/29.
//

import SwiftUI
import CoreLocation
import AVFoundation
import AMapFoundationKit
import AMapLocationKit
import AMapSearchKit
import MAMapKit

// MARK: - 垃圾箱标注
class TrashBinAnnotation: MAPointAnnotation {
    var trashBin: TrashBinData?
}

// MARK: - 定位管理器
class AMapLocationService: NSObject, CLLocationManagerDelegate {
    static let shared = AMapLocationService()

    private let clManager = CLLocationManager()
    private var didAuthorize = false
    private var pendingCompletion: ((CLLocationCoordinate2D?) -> Void)?
    var currentLocation: CLLocationCoordinate2D?

    override init() {
        super.init()
        clManager.delegate = self
        clManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestPermission() {
        DispatchQueue.main.async {
            self.clManager.requestWhenInUseAuthorization()
        }
    }

    func requestLocation(completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        let status = clManager.authorizationStatus
        print("当前定位权限状态: \(status.rawValue)")

        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            doRequestLocation(completion: completion)
        case .notDetermined:
            pendingCompletion = completion
            requestPermission()
        case .denied, .restricted:
            print("⚠️ 定位权限被拒绝")
            completion(nil)
        @unknown default:
            completion(nil)
        }
    }

    private func doRequestLocation(completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        let aMapManager = AMapLocationManager()
        aMapManager.desiredAccuracy = kCLLocationAccuracyBest
        aMapManager.locationTimeout = 10
        aMapManager.reGeocodeTimeout = 10

        aMapManager.requestLocation(withReGeocode: true) { [weak self] location, reGeocode, error in
            if let error = error {
                print("定位失败: \(error.localizedDescription)")
                completion(nil)
                return
            }
            if let location = location {
                print("✅ 定位成功: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                self?.currentLocation = location.coordinate
                completion(location.coordinate)
            } else {
                completion(nil)
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        print("定位权限状态变更: \(status.rawValue)")

        if status == .authorizedWhenInUse || status == .authorizedAlways {
            didAuthorize = true
            if let completion = pendingCompletion {
                pendingCompletion = nil
                doRequestLocation(completion: completion)
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("CLLocationManager 错误: \(error.localizedDescription)")
    }
}

// MARK: - 通知扩展
extension Notification.Name {
    static let resetMapHeading = Notification.Name("resetMapHeading")
}

// MARK: - 地图 UIViewRepresentable
struct MapView: UIViewRepresentable {
    @Binding var locationText: String
    @Binding var selectedTrashBin: TrashBinData?
    @Binding var showTrashBinInfo: Bool
    @Binding var shouldRecenter: Bool
    @Binding var isHeadingMode: Bool
    var refreshTrigger: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MAMapView {
        let mapView = MAMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .followWithHeading  // 启用朝向追踪（显示朝向指示器）
        mapView.zoomLevel = 19
        mapView.showsCompass = false
        mapView.showsScale = true
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = true  // 允许地图旋转

        // 设置朝向指示器样式（绿色）
        let representation = MAUserLocationRepresentation()
        representation.showsHeadingIndicator = true
        representation.fillColor = UIColor.systemGreen.withAlphaComponent(0.3)
        representation.strokeColor = UIColor.systemGreen
        representation.lineWidth = 1.5
        representation.enablePulseAnnimation = true
        mapView.update(representation)

        context.coordinator.mapView = mapView
        context.coordinator.loadAndAddAnnotations()

        return mapView
    }

    func updateUIView(_ uiView: MAMapView, context: Context) {
        if shouldRecenter {
            context.coordinator.recenterMap()
            DispatchQueue.main.async {
                shouldRecenter = false
            }
        }

        // 刷新标注
        if refreshTrigger != context.coordinator.lastRefreshTrigger {
            context.coordinator.lastRefreshTrigger = refreshTrigger
            context.coordinator.refreshAllAnnotations()
        }
    }

    // MARK: - Coordinator
    class Coordinator: NSObject, MAMapViewDelegate, AMapSearchDelegate {
        var parent: MapView
        var search: AMapSearchAPI?
        var currentRoute: MAPolyline?
        var mapView: MAMapView?
        var trashBins: [TrashBinData] = []
        var lastRefreshTrigger: Bool = false
        var userCoordinate: CLLocationCoordinate2D?
        let loginManager = LoginManager.shared

        init(_ parent: MapView) {
            self.parent = parent
            super.init()
            self.search = AMapSearchAPI()
            self.search?.delegate = self

            // 监听重置地图朝向通知
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleResetMapHeading),
                name: .resetMapHeading,
                object: nil
            )
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        @objc func handleResetMapHeading() {
            guard let mapView = mapView else { return }
            // 重置地图旋转角度为正北方向
            mapView.setRotationDegree(0, animated: true, duration: 0.3)
            // 恢复朝向追踪模式
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                mapView.userTrackingMode = .followWithHeading
                // 重新设置朝向指示器样式
                let representation = MAUserLocationRepresentation()
                representation.showsHeadingIndicator = true
                representation.fillColor = UIColor.systemGreen.withAlphaComponent(0.3)
                representation.strokeColor = UIColor.systemGreen
                representation.lineWidth = 1.5
                representation.enablePulseAnnimation = true
                mapView.update(representation)
            }
        }

        func loadAndAddAnnotations() {
            trashBins = TrashBinDataManager.shared.loadTrashBins()
            addAnnotationsToMap()
        }

        // 刷新所有标注（强制重绘）
        func refreshAllAnnotations() {
            guard let mapView = mapView else { return }

            // 移除所有垃圾箱标注
            let oldAnnotations = mapView.annotations.filter { $0 is TrashBinAnnotation }
            mapView.removeAnnotations(oldAnnotations)

            // 重新加载数据并添加标注
            trashBins = TrashBinDataManager.shared.loadTrashBins()
            addAnnotationsToMap()
        }

        func recenterMap() {
            guard let mapView = mapView else { return }

            if let route = currentRoute {
                mapView.remove(route)
                currentRoute = nil
            }

            if let userLocation = mapView.userLocation?.coordinate,
               userLocation.latitude != 0 && userLocation.longitude != 0 {
                mapView.setCenter(userLocation, animated: true)
                mapView.zoomLevel = 17
            } else {
                let defaultLocation = CLLocationCoordinate2D(latitude: 32.024963, longitude: 118.912718)
                mapView.setCenter(defaultLocation, animated: true)
                mapView.zoomLevel = 17
            }

            DispatchQueue.main.async {
                self.parent.showTrashBinInfo = false
                self.parent.selectedTrashBin = nil
            }
        }

        private func addAnnotationsToMap() {
            guard let mapView = mapView else { return }

            let oldAnnotations = mapView.annotations.filter { $0 is TrashBinAnnotation }
            mapView.removeAnnotations(oldAnnotations)

            // 获取用户当前位置
            let userLocation = mapView.userLocation?.coordinate ?? userCoordinate

            var annotations: [TrashBinAnnotation] = []
            for trashBin in trashBins {
                let annotation = TrashBinAnnotation()
                annotation.coordinate = trashBin.coordinate
                annotation.title = trashBin.name

                // 计算距离
                var distanceText = ""
                if let userLoc = userLocation {
                    let userCLLocation = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
                    let binCLLocation = CLLocation(latitude: trashBin.latitude, longitude: trashBin.longitude)
                    let distance = userCLLocation.distance(from: binCLLocation)

                    if distance >= 1000 {
                        distanceText = String(format: "%.1fkm", distance / 1000)
                    } else {
                        distanceText = "\(Int(distance))m"
                    }
                }

                // 格式: "距离 | 类型 | 地址"
                let parts = [distanceText, trashBin.typeName, trashBin.address ?? ""].filter { !$0.isEmpty }
                annotation.subtitle = parts.joined(separator: " | ")

                annotation.trashBin = trashBin
                annotations.append(annotation)
            }
            mapView.addAnnotations(annotations)
        }

        func refreshAnnotations() {
            loadAndAddAnnotations()
        }

        // MARK: - MAMapViewDelegate

        func mapView(_ mapView: MAMapView!, didUpdate userLocation: MAUserLocation!, updatingLocation: Bool) {
            if updatingLocation, let coordinate = userLocation?.coordinate {
                let lat = String(format: "%.6f", coordinate.latitude)
                let lon = String(format: "%.6f", coordinate.longitude)
                parent.locationText = "\(lat), \(lon)"
                userCoordinate = coordinate
                // 同步更新到 AMapLocationService
                AMapLocationService.shared.currentLocation = coordinate
            }
        }

        // 取消选中标注时关闭信息卡片
        func mapView(_ mapView: MAMapView!, didDeselect view: MAAnnotationView!) {
            print("🔘 取消选中标注，关闭信息卡片")
            DispatchQueue.main.async {
                self.parent.showTrashBinInfo = false
                self.parent.selectedTrashBin = nil
            }
        }

        // 用户跟踪模式改变（拖拽地图时触发）
        func mapView(_ mapView: MAMapView!, didChange mode: MAUserTrackingMode, animated: Bool) {
            print("📍 跟踪模式改变: \(mode.rawValue)")
            // 通知父视图更新朝向按钮状态
            DispatchQueue.main.async {
                self.parent.isHeadingMode = (mode == .followWithHeading)
            }
        }

        // 自定义标注视图
        func mapView(_ mapView: MAMapView!, viewFor annotation: MAAnnotation!) -> MAAnnotationView! {
            // 用户位置使用默认视图（不自定义，否则朝向指示器失效）
            if annotation is MAUserLocation {
                return nil  // 返回 nil 使用默认样式
            }

            if let trashBinAnnotation = annotation as? TrashBinAnnotation {
                let identifier = "TrashBinAnnotation"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MAPinAnnotationView

                if annotationView == nil {
                    annotationView = MAPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                    annotationView?.animatesDrop = true
                } else {
                    annotationView?.annotation = annotation
                }

                if let trashBin = trashBinAnnotation.trashBin {
                    // 判断是否是用户自己发现的
                    let currentUserName = loginManager.userName
                    let isMine = trashBin.discoverer == currentUserName && !currentUserName.isEmpty
                    let iconSize: CGFloat = isMine ? 33 : 20  // 用户发现的大1/3
                    let iconContainerSize: CGFloat = isMine ? 40 : 24

                    // 检查用户自定义图标
                    if let customIconPath = TrashBinDataManager.shared.getCustomIconPath(trashBinId: trashBin.id),
                       let customImage = UIImage(contentsOfFile: customIconPath) {
                        let resizedImage = resizeImage(customImage, to: CGSize(width: iconSize, height: iconSize))
                        annotationView?.image = resizedImage
                    } else {
                        // 统一使用黑色垃圾桶图标（透明背景，黑色填充）
                        let config = UIImage.SymbolConfiguration(pointSize: iconSize, weight: .medium)
                        if let iconImage = UIImage(systemName: "trash.fill", withConfiguration: config) {
                            let renderer = UIGraphicsImageRenderer(size: CGSize(width: iconContainerSize, height: iconContainerSize))
                            let finalImage = renderer.image { context in
                                let offset = (iconContainerSize - iconSize) / 2
                                let iconRect = CGRect(x: offset, y: offset, width: iconSize, height: iconSize)
                                iconImage.withTintColor(.black).draw(in: iconRect)
                            }
                            annotationView?.image = finalImage
                        }
                    }
                }

                return annotationView
            }
            return nil
        }

        // 点击标注
        func mapView(_ mapView: MAMapView!, didSelect view: MAAnnotationView!) {
            if let trashBinAnnotation = view.annotation as? TrashBinAnnotation,
               let trashBin = trashBinAnnotation.trashBin {
                // 重新计算距离
                if let userLoc = userCoordinate {
                    let userCLLocation = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
                    let binCLLocation = CLLocation(latitude: trashBin.latitude, longitude: trashBin.longitude)
                    let distance = userCLLocation.distance(from: binCLLocation)

                    let distanceText: String
                    if distance >= 1000 {
                        distanceText = String(format: "%.1fkm", distance / 1000)
                    } else {
                        distanceText = "\(Int(distance))m"
                    }

                    // 更新气泡显示
                    let parts = [distanceText, trashBin.typeName, trashBin.address ?? ""].filter { !$0.isEmpty }
                    trashBinAnnotation.subtitle = parts.joined(separator: " | ")
                }

                DispatchQueue.main.async {
                    self.parent.selectedTrashBin = trashBin
                    self.parent.showTrashBinInfo = true
                }
                mapView.setCenter(trashBinAnnotation.coordinate, animated: true)
            }
        }

        // MARK: - 路线计算

        func calculateRoute(to destination: CLLocationCoordinate2D, mapView: MAMapView) {
            guard let userLocation = mapView.userLocation?.coordinate else {
                print("无法获取用户位置")
                return
            }

            if let oldRoute = currentRoute {
                mapView.remove(oldRoute)
                currentRoute = nil
            }

            let request = AMapWalkingRouteSearchRequest()
            request.origin = AMapGeoPoint.location(withLatitude: CGFloat(userLocation.latitude), longitude: CGFloat(userLocation.longitude))
            request.destination = AMapGeoPoint.location(withLatitude: CGFloat(destination.latitude), longitude: CGFloat(destination.longitude))

            search?.aMapWalkingRouteSearch(request)
        }

        // MARK: - AMapSearchDelegate

        func onRouteSearchDone(_ request: AMapRouteSearchBaseRequest!, response: AMapRouteSearchResponse!) {
            guard let route = response.route,
                  let paths = route.paths,
                  let firstPath = paths.first else {
                print("路线规划失败")
                return
            }

            if let steps = firstPath.steps {
                var coordinates: [CLLocationCoordinate2D] = []

                for step in steps {
                    if let polyline = step.polyline {
                        let points = polyline.components(separatedBy: ";")
                        for point in points {
                            let parts = point.components(separatedBy: ",")
                            if parts.count == 2,
                               let lon = Double(parts[0]),
                               let lat = Double(parts[1]) {
                                coordinates.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
                            }
                        }
                    }
                }

                if !coordinates.isEmpty {
                    let polyline = MAPolyline(coordinates: &coordinates, count: UInt(coordinates.count))
                    DispatchQueue.main.async {
                        self.currentRoute = polyline
                        self.mapView?.add(polyline)
                    }
                }
            }
        }

        func aMapSearchRequest(_ request: Any!, didFailWithError error: Error!) {
            print("搜索失败: \(error.localizedDescription)")
        }

        private func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage {
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { context in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
        }
    }
}

// MARK: - 路线覆盖层渲染
extension MapView.Coordinator {
    func mapView(_ mapView: MAMapView!, rendererFor overlay: MAOverlay!) -> MAOverlayRenderer! {
        if let polyline = overlay as? MAPolyline {
            let renderer = MAPolylineRenderer(polyline: polyline)
            renderer?.strokeColor = UIColor.systemBlue
            renderer?.lineWidth = 6.0
            renderer?.lineJoinType = kMALineJoinRound
            renderer?.lineCapType = kMALineCapRound
            return renderer
        }
        return nil
    }
}

// MARK: - 主视图
struct MapContainerView: View {
    @State private var locationText: String = "定位中..."
    @State private var showLogin: Bool = false
    @State private var showMy: Bool = false
    @State private var selectedTrashBin: TrashBinData? = nil
    @State private var isNavigating: Bool = false
    @State private var shouldRecenter: Bool = false
    @State private var showTrashBinInfo: Bool = false
    @State private var showTrashBinList: Bool = false
    @State private var trashBins: [TrashBinData] = []
    @State private var refreshTrigger: Bool = false
    @State private var isHeadingMode: Bool = true
    @State private var showCamera: Bool = false
    @State private var capturedImage: UIImage? = nil
    @State private var showNoTrashBinAlert: Bool = false
    @State private var showDiscoverPage: Bool = false
    @State private var showCameraPermissionAlert: Bool = false
    @State private var showLoginRequiredAlert: Bool = false
    @ObservedObject var loginManager = LoginManager.shared

    var body: some View {
        ZStack(alignment: .bottom) {
            MapView(
                locationText: $locationText,
                selectedTrashBin: $selectedTrashBin,
                showTrashBinInfo: $showTrashBinInfo,
                shouldRecenter: $shouldRecenter,
                isHeadingMode: $isHeadingMode,
                refreshTrigger: refreshTrigger
            )
            .ignoresSafeArea()

            // 底部位置信息（仅在没有选择垃圾箱时显示）
            if !showTrashBinInfo && !showTrashBinList {
                VStack(spacing: 4) {
                    Text("当前位置")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(locationText)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .padding(.bottom, 30)
            }

            // 垃圾箱信息卡片（底部显示）
            if showTrashBinInfo, let trashBin = selectedTrashBin {
                VStack {
                    Spacer()
                    TrashBinInfoCard(
                        trashBin: trashBin,
                        isPresented: $showTrashBinInfo
                    )
                }
                .transition(.move(edge: .bottom))
                .animation(.easeInOut(duration: 0.3), value: showTrashBinInfo)
                .allowsHitTesting(true)  // 允许点击信息卡片
                .onTapGesture {}  // 阻止点击穿透
            }

            // 右下角按钮区域
            VStack(spacing: 12) {
                Spacer()
                    .frame(maxHeight: showTrashBinInfo ? .infinity : nil)

                if !showTrashBinInfo {
                    HStack {
                        Spacer()

                        VStack(spacing: 12) {
                            // 指南针按钮（点击回正地图并恢复朝向追踪）
                            Button(action: {
                                NotificationCenter.default.post(name: .resetMapHeading, object: nil)
                                // 恢复朝向追踪模式
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    isHeadingMode = true
                                }
                            }) {
                                Image(systemName: isHeadingMode ? "location.north.line.fill" : "safari")
                                    .font(.system(size: 20))
                                    .foregroundColor(isHeadingMode ? .green : .red)
                                    .frame(width: 44, height: 44)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(22)
                                    .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
                            }

                            // 发现按钮（拍照识别垃圾箱）- 需要登录
                            Button(action: {
                                LoginGuard.check(
                                    isLoggedIn: loginManager.isLoggedIn,
                                    showLogin: $showLogin
                                ) {
                                    checkCameraPermission()
                                }
                            }) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.purple)
                                    .frame(width: 44, height: 44)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(22)
                                    .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
                            }

                            // 垃圾箱列表按钮
                            Button(action: {
                                trashBins = TrashBinDataManager.shared.loadTrashBins()
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showTrashBinList = true
                                }
                            }) {
                                Image(systemName: "list.bullet")
                                    .font(.system(size: 20))
                                    .foregroundColor(.green)
                                    .frame(width: 44, height: 44)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(22)
                                    .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
                            }

                            // 定位按钮
                            Button(action: {
                                showTrashBinInfo = false
                                selectedTrashBin = nil
                                shouldRecenter = true
                            }) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.blue)
                                    .frame(width: 44, height: 44)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(22)
                                    .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
                            }

                            // 登录/我的按钮
                            Button(action: {
                                if loginManager.isLoggedIn {
                                    showMy = true
                                } else {
                                    showLogin = true
                                }
                            }) {
                                VStack(spacing: 4) {
                                    Image(systemName: loginManager.isLoggedIn ? "person.fill" : "person")
                                        .font(.system(size: 22))
                                    Text(loginManager.isLoggedIn ? "我的" : "登录")
                                        .font(.caption2)
                                }
                                .foregroundColor(.blue)
                                .frame(width: 56, height: 56)
                                .background(.ultraThinMaterial)
                                .cornerRadius(28)
                                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                            }
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 30)
                    }
                }
            }

            // 垃圾箱列表
            if showTrashBinList {
                TrashBinListView(
                    isPresented: $showTrashBinList,
                    selectedTrashBin: $selectedTrashBin,
                    showTrashBinInfo: $showTrashBinInfo,
                    refreshTrigger: $refreshTrigger,
                    initialTrashBins: trashBins,
                    initialUserLocation: AMapLocationService.shared.currentLocation
                )
                .transition(.move(edge: .trailing))
                .animation(.easeInOut(duration: 0.3), value: showTrashBinList)
                .zIndex(1)
            }

            // 导航模式提示
            if isNavigating {
                VStack {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.green)
                        Text("导航中...")
                            .font(.headline)
                            .foregroundColor(.green)
                        Spacer()
                        Button(action: {
                            isNavigating = false
                        }) {
                            Text("结束导航")
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .padding(.top, 60)
                    .padding(.horizontal, 16)

                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
        .sheet(isPresented: $showMy) {
            MyView()
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(
                isPresented: $showCamera,
                capturedImage: $capturedImage,
                onCapture: { image in
                    // 检测图片中是否包含垃圾箱
                    TrashBinDetector.shared.detectTrashBin(in: image) { result in
                        if result.hasTrashBin {
                            // 检测到垃圾箱，进入发现页面
                            showDiscoverPage = true
                        } else {
                            // 未检测到垃圾箱，提示重新拍照
                            showNoTrashBinAlert = true
                        }
                    }
                }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showDiscoverPage) {
            if let image = capturedImage {
                DiscoverTrashBinView(
                    capturedImage: image,
                    isPresented: $showDiscoverPage
                )
            }
        }
        .alert("照片中无垃圾箱元素", isPresented: $showNoTrashBinAlert) {
            Button("重新拍照") {
                checkCameraPermission()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("请重新拍照，确保照片中包含垃圾箱")
        }
        .alert("相机权限未开启", isPresented: $showCameraPermissionAlert) {
            Button("去开启") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("关闭", role: .cancel) {}
        } message: {
            Text("需要获取相机权限才能拍照，请在设置中开启相机权限")
        }
    }

    // 检查相机权限
    private func checkCameraPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        print("📷 相机权限状态: \(status.rawValue)")

        switch status {
        case .authorized:
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showCamera = true
                    } else {
                        showCameraPermissionAlert = true
                    }
                }
            }
        case .denied, .restricted:
            showCameraPermissionAlert = true
        @unknown default:
            break
        }
    }
}

#Preview {
    MapContainerView()
}
