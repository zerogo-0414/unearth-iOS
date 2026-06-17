//
//  DeleteAccountView.swift
//  Unearth
//
//  Created by Theo on 2026/6/11.
//

import SwiftUI

// MARK: - 用户注销页面
struct DeleteAccountView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var loginManager = LoginManager.shared

    // 图形验证码
    @State private var captchaImage: UIImage? = nil
    @State private var captchaId: String = ""
    @State private var captchaCode: String = ""

    // 短信验证码
    @State private var smsCode: String = ""
    @State private var codeSent: Bool = false
    @State private var countdown: Int = 60

    // 状态
    @State private var isLoading: Bool = false
    @State private var showSuccess: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var showConfirmAlert: Bool = false

    private var isSmsCodeValid: Bool {
        smsCode.count == 6
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 警告图标
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                        .padding(.top, 40)

                    // 警告标题
                    Text("注销账号")
                        .font(.title2)
                        .fontWeight(.bold)

                    // 警告内容
                    VStack(alignment: .leading, spacing: 12) {
                        Text("注销账号后，以下信息将被永久删除且无法恢复：")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        WarningRow(icon: "trash.fill", text: "所有发现的垃圾箱记录")
                        WarningRow(icon: "heart.fill", text: "所有点赞和收藏记录")
                        WarningRow(icon: "star.fill", text: "积分和等级数据")
                        WarningRow(icon: "person.fill", text: "个人资料和头像")
                        WarningRow(icon: "photo.fill", text: "上传的所有图片")

                        Text("此操作不可逆，请谨慎操作！")
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .fontWeight(.medium)
                            .padding(.top, 8)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // 验证身份
                    VStack(alignment: .leading, spacing: 16) {
                        Text("验证身份")
                            .font(.headline)

                        // 手机号（只读）
                        HStack {
                            Image(systemName: "phone.fill")
                                .foregroundColor(.gray)
                                .frame(width: 24)
                            Text(loginManager.phoneNumber)
                                .font(.subheadline)
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)

                        // 图形验证码
                        HStack(spacing: 12) {
                            Image(systemName: "textformat.abc")
                                .foregroundColor(.gray)
                                .frame(width: 24)

                            TextField("请输入图形验证码", text: $captchaCode)
                                .textContentType(.oneTimeCode)

                            // 图形验证码图片
                            if let image = captchaImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 40)
                                    .cornerRadius(4)
                                    .onTapGesture {
                                        refreshCaptcha()
                                    }
                            } else {
                                Button(action: refreshCaptcha) {
                                    Text("获取验证码")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)

                        // 短信验证码
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.gray)
                                .frame(width: 24)

                            TextField("请输入短信验证码", text: $smsCode)
                                .keyboardType(.numberPad)
                                .textContentType(.oneTimeCode)

                            Button(action: sendSmsCode) {
                                Text(codeSent ? "\(countdown)s" : "获取验证码")
                                    .font(.subheadline)
                                    .foregroundColor(codeSent ? .gray : .blue)
                            }
                            .disabled(codeSent || captchaCode.isEmpty)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)

                    // 注销按钮
                    Button(action: {
                        showConfirmAlert = true
                    }) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text("确认注销")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isSmsCodeValid ? Color.red : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!isSmsCodeValid || isLoading)
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("注销账号")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("返回") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                refreshCaptcha()
            }
            .alert("确认注销", isPresented: $showConfirmAlert) {
                Button("确认注销", role: .destructive) {
                    deleteAccount()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("注销后所有数据将被永久删除，确定要继续吗？")
            }
            .alert("注销成功", isPresented: $showSuccess) {
                Button("确定") {
                    loginManager.logout()
                    dismiss()
                }
            } message: {
                Text("您的账号已成功注销")
            }
            .alert("提示", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // 刷新图形验证码
    private func refreshCaptcha() {
        captchaCode = ""

        APIService.shared.getCaptcha { result in
            switch result {
            case .success(let response):
                if let data = response.data {
                    captchaId = data.captchaId
                    // 解码 Base64 图片
                    if let imageData = Data(base64Encoded: data.image),
                       let image = UIImage(data: imageData) {
                        captchaImage = image
                    }
                }
            case .failure(let error):
                print("获取验证码失败: \(error)")
                errorMessage = "获取验证码失败，请重试"
                showError = true
            }
        }
    }

    // 发送短信验证码
    private func sendSmsCode() {
        guard !captchaCode.isEmpty else { return }

        codeSent = true
        countdown = 60

        APIService.shared.sendCode(
            phone: loginManager.phoneNumber,
            captchaId: captchaId,
            captchaCode: captchaCode
        ) { result in
            switch result {
            case .success:
                print("短信验证码发送成功")
            case .failure(let error):
                print("短信验证码发送失败: \(error)")
                errorMessage = "验证码发送失败，请检查图形验证码是否正确"
                showError = true
                codeSent = false
                refreshCaptcha()
            }
        }

        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if countdown > 0 {
                countdown -= 1
            } else {
                timer.invalidate()
                codeSent = false
            }
        }
    }

    // 注销账号
    private func deleteAccount() {
        guard isSmsCodeValid else { return }

        isLoading = true

        APIService.shared.deleteAccount(
            phone: loginManager.phoneNumber,
            code: smsCode
        ) { result in
            isLoading = false

            switch result {
            case .success:
                showSuccess = true
            case .failure(let error):
                errorMessage = "注销失败: \(error.localizedDescription)"
                showError = true
                smsCode = ""
                refreshCaptcha()
            }
        }
    }
}

// MARK: - 警告行
struct WarningRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.red)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    DeleteAccountView()
}
