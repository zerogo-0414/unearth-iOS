//
//  CameraView.swift
//  Unearth
//
//  Created by Theo on 2026/6/9.
//

import SwiftUI
import AVFoundation
import UIKit

// MARK: - 相机视图
struct CameraView: View {
    @Binding var isPresented: Bool
    @Binding var capturedImage: UIImage?
    var onCapture: (UIImage) -> Void

    var body: some View {
        CameraViewControllerWrapper(
            isPresented: $isPresented,
            capturedImage: $capturedImage,
            onCapture: onCapture
        )
        .ignoresSafeArea()
    }
}

// MARK: - 相机 UIViewController 封装
struct CameraViewControllerWrapper: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    @Binding var capturedImage: UIImage?
    var onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> CameraViewController {
        let vc = CameraViewController()
        vc.onCapture = { [self] image in
            capturedImage = image
            onCapture(image)
            isPresented = false
        }
        vc.onCancel = { [self] in
            isPresented = false
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
}

// MARK: - 相机 UIViewController
class CameraViewController: UIViewController {
    var onCapture: ((UIImage) -> Void)?
    var onCancel: (() -> Void)?

    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var currentPosition: AVCaptureDevice.Position = .back

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupUI()
        checkCameraPermission()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupCamera()
                    } else {
                        self?.showPermissionAlert()
                    }
                }
            }
        case .denied, .restricted:
            showPermissionAlert()
        @unknown default:
            break
        }
    }

    private func showPermissionAlert() {
        let alert = UIAlertController(
            title: "相机权限未开启",
            message: "需要获取相机权限才能拍照，请在设置中开启",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "去开启", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        alert.addAction(UIAlertAction(title: "关闭", style: .cancel) { [weak self] _ in
            self?.onCancel?()
        })
        present(alert, animated: true)
    }

    private func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .photo

        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("无法获取后置摄像头")
            showCameraFailureAlert()
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            if captureSession?.canAddInput(input) == true {
                captureSession?.addInput(input)
            } else {
                showCameraFailureAlert()
                return
            }

            photoOutput = AVCapturePhotoOutput()
            if captureSession?.canAddOutput(photoOutput!) == true {
                captureSession?.addOutput(photoOutput!)
            } else {
                showCameraFailureAlert()
                return
            }

            // 设置预览层
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
            previewLayer?.videoGravity = .resizeAspectFill
            previewLayer?.frame = view.bounds
            view.layer.insertSublayer(previewLayer!, at: 0)

            // 在后台线程启动 session
            DispatchQueue.global(qos: .background).async { [weak self] in
                self?.captureSession?.startRunning()
            }
        } catch {
            print("相机设置错误: \(error)")
            showCameraFailureAlert()
        }
    }

    private func showCameraFailureAlert() {
        let alert = UIAlertController(
            title: "获取摄像头失败",
            message: "无法启动相机，请重试或关闭页面",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "重试", style: .default) { [weak self] _ in
            self?.setupCamera()
        })
        alert.addAction(UIAlertAction(title: "关闭", style: .cancel) { [weak self] _ in
            self?.onCancel?()
        })
        present(alert, animated: true)
    }

    private func setupUI() {
        // 返回按钮
        let cancelButton = UIButton(type: .system)
        cancelButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        cancelButton.tintColor = .white
        cancelButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        cancelButton.layer.cornerRadius = 22
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cancelButton)

        // 拍照按钮
        let captureButton = UIButton(type: .system)
        captureButton.backgroundColor = .white
        captureButton.layer.cornerRadius = 35
        captureButton.addTarget(self, action: #selector(captureTapped), for: .touchUpInside)
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(captureButton)

        // 翻转按钮
        let flipButton = UIButton(type: .system)
        flipButton.setImage(UIImage(systemName: "camera.rotate.fill"), for: .normal)
        flipButton.tintColor = .white
        flipButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        flipButton.layer.cornerRadius = 22
        flipButton.addTarget(self, action: #selector(flipTapped), for: .touchUpInside)
        flipButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(flipButton)

        NSLayoutConstraint.activate([
            // 返回按钮（左下角）
            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            cancelButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            cancelButton.widthAnchor.constraint(equalToConstant: 44),
            cancelButton.heightAnchor.constraint(equalToConstant: 44),

            // 拍照按钮（底部中间）
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            captureButton.widthAnchor.constraint(equalToConstant: 70),
            captureButton.heightAnchor.constraint(equalToConstant: 70),

            // 翻转按钮（右下角）
            flipButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            flipButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            flipButton.widthAnchor.constraint(equalToConstant: 44),
            flipButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    @objc private func cancelTapped() {
        captureSession?.stopRunning()
        onCancel?()
    }

    @objc private func captureTapped() {
        guard let photoOutput = photoOutput else { return }
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    @objc private func flipTapped() {
        guard let session = captureSession else { return }

        currentPosition = currentPosition == .back ? .front : .back

        guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentPosition) else {
            return
        }

        do {
            let newInput = try AVCaptureDeviceInput(device: newCamera)

            session.beginConfiguration()

            // 移除现有输入
            for input in session.inputs {
                session.removeInput(input)
            }

            // 添加新输入
            if session.canAddInput(newInput) {
                session.addInput(newInput)
            }

            session.commitConfiguration()
        } catch {
            print("切换摄像头失败: \(error)")
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("拍照失败: \(error)")
            return
        }

        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("无法获取图片数据")
            return
        }

        captureSession?.stopRunning()

        DispatchQueue.main.async { [weak self] in
            self?.onCapture?(image)
        }
    }
}

// MARK: - 垃圾箱检测结果
struct TrashBinDetectionResult {
    let hasTrashBin: Bool
    let confidence: Double
    let description: String
}

// MARK: - 垃圾箱检测器
class TrashBinDetector {
    static let shared = TrashBinDetector()

    func detectTrashBin(in image: UIImage, completion: @escaping (TrashBinDetectionResult) -> Void) {
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1.0) {
            let result = TrashBinDetectionResult(
                hasTrashBin: true,
                confidence: 0.85,
                description: "检测到垃圾箱"
            )
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
}

// MARK: - UIImagePickerController 封装
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    var onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
                parent.onImagePicked(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
