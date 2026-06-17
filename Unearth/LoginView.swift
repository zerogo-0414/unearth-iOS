//
//  LoginView.swift
//  Unearth
//
//  Created by Theo on 2026/6/9.
//

import SwiftUI
import Combine

// MARK: - Mock 账号
struct MockAccount: Identifiable {
    let id = UUID()
    let name: String
    let phone: String
    let code: String
    let avatar: String
}

let mockAccounts: [MockAccount] = [
    MockAccount(name: "张三", phone: "13800138001", code: "123456", avatar: "person.circle.fill"),
    MockAccount(name: "李四", phone: "13900139002", code: "654321", avatar: "person.circle.fill"),
    MockAccount(name: "王五", phone: "15000150003", code: "111111", avatar: "person.circle.fill")
]

// MARK: - 登录状态管理
class LoginManager: ObservableObject {
    static let shared = LoginManager()

    @Published var isLoggedIn: Bool = false
    @Published var phoneNumber: String = ""
    @Published var userName: String = ""
    @Published var userId: Int = 0

    private init() {
        isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
        phoneNumber = UserDefaults.standard.string(forKey: "phoneNumber") ?? ""
        userName = UserDefaults.standard.string(forKey: "userName") ?? ""
        userId = UserDefaults.standard.integer(forKey: "userId")
    }

    func login(phone: String, name: String = "", userId: Int = 0) {
        phoneNumber = phone
        userName = name
        self.userId = userId
        isLoggedIn = true
        UserDefaults.standard.set(true, forKey: "isLoggedIn")
        UserDefaults.standard.set(phone, forKey: "phoneNumber")
        UserDefaults.standard.set(name, forKey: "userName")
        UserDefaults.standard.set(userId, forKey: "userId")
    }

    func logout() {
        // 调用后端登出
        if APIConfig.authToken != nil {
            // APIService.shared.logout { _ in }
        }

        phoneNumber = ""
        userName = ""
        userId = 0
        isLoggedIn = false
        APIConfig.authToken = nil
        UserDefaults.standard.set(false, forKey: "isLoggedIn")
        UserDefaults.standard.removeObject(forKey: "phoneNumber")
        UserDefaults.standard.removeObject(forKey: "userName")
        UserDefaults.standard.removeObject(forKey: "userId")
    }
}

// MARK: - 登录页面
struct LoginView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var loginManager = LoginManager.shared

    @State private var phoneNumber: String = ""
    @State private var verificationCode: String = ""
    @State private var isLoading: Bool = false
    @State private var codeSent: Bool = false
    @State private var countdown: Int = 60
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    // 图形验证码
    @State private var captchaImage: UIImage? = nil
    @State private var captchaId: String = ""
    @State private var captchaCode: String = ""

    private var isPhoneValid: Bool {
        phoneNumber.count == 11 && phoneNumber.hasPrefix("1")
    }

    private var isCodeValid: Bool {
        verificationCode.count == 6
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 60)

                // Logo
                Image(systemName: "map.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .padding(.bottom, 16)

                Text("Unearth")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.bottom, 40)

                // 输入区域
                VStack(spacing: 16) {
                    // 手机号输入
                    HStack {
                        Image(systemName: "phone.fill")
                            .foregroundColor(.gray)
                            .frame(width: 24)

                        TextField("请输入手机号", text: $phoneNumber)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)

                        if !phoneNumber.isEmpty {
                            Button(action: { phoneNumber = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // 图形验证码（自动加载）
                    HStack(spacing: 12) {
                        Image(systemName: "textformat.abc")
                            .foregroundColor(.gray)
                            .frame(width: 24)

                        TextField("输入图形验证码", text: $captchaCode)
                            .textContentType(.oneTimeCode)

                        if let image = captchaImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 36)
                                .cornerRadius(4)
                                .onTapGesture {
                                    refreshCaptcha()
                                }
                        } else {
                            ProgressView()
                                .frame(width: 80, height: 36)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // 短信验证码输入
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.gray)
                            .frame(width: 24)

                        TextField("请输入短信验证码", text: $verificationCode)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)

                        Button(action: sendCode) {
                            Text(codeSent ? "\(countdown)s" : "获取验证码")
                                .font(.subheadline)
                                .foregroundColor(codeSent ? .gray : .blue)
                        }
                        .disabled(!isPhoneValid || codeSent || captchaCode.isEmpty)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 32)

                // 登录按钮
                Button(action: login) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text("登录")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isPhoneValid && isCodeValid ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!isPhoneValid || !isCodeValid || isLoading)
                .padding(.horizontal, 32)
                .padding(.top, 24)

                // 协议
                HStack(spacing: 4) {
                    Text("登录即表示同意")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Button("《用户协议》") {}
                        .font(.caption)
                    Text("和")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Button("《隐私政策》") {}
                        .font(.caption)
                }
                .padding(.top, 16)

                Spacer()

                // Mock 账号快速登录
                VStack(spacing: 12) {
                    Text("测试账号快速登录")
                        .font(.caption)
                        .foregroundColor(.gray)

                    HStack(spacing: 12) {
                        ForEach(mockAccounts) { account in
                            Button(action: {
                                quickLogin(account: account)
                            }) {
                                VStack(spacing: 6) {
                                    Image(systemName: account.avatar)
                                        .font(.system(size: 28))
                                        .foregroundColor(.blue)
                                    Text(account.name)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                    Text(account.phone)
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                }
                .padding(.bottom, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                    }
                }
            }
            .onAppear {
                // 自动加载图形验证码
                refreshCaptcha()
            }
            .alert("提示", isPresented: $showError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // 快速登录（Mock）
    private func quickLogin(account: MockAccount) {
        phoneNumber = account.phone
        verificationCode = account.code
        loginManager.login(phone: account.phone, name: account.name)
        dismiss()
    }

    // 刷新图形验证码
    private func refreshCaptcha() {
        captchaCode = ""

        APIService.shared.getCaptcha { result in
            switch result {
            case .success(let response):
                if let data = response.data {
                    captchaId = data.captchaId
                    if let imageData = Data(base64Encoded: data.image),
                       let image = UIImage(data: imageData) {
                        captchaImage = image
                    }
                }
            case .failure(let error):
                print("获取验证码失败: \(error)")
            }
        }
    }

    // 发送验证码
    private func sendCode() {
        guard isPhoneValid else { return }

        // 需要输入图形验证码
        guard !captchaCode.isEmpty else {
            errorMessage = "请先输入图形验证码"
            showError = true
            return
        }

        codeSent = true
        countdown = 60

        // 调用后端发送验证码
        APIService.shared.sendCode(
            phone: phoneNumber,
            captchaId: captchaId,
            captchaCode: captchaCode
        ) { result in
            switch result {
            case .success:
                print("验证码发送成功")
            case .failure(let error):
                print("验证码发送失败: \(error)")
                errorMessage = "验证码发送失败，请检查图形验证码"
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

    // 登录
    private func login() {
        guard isPhoneValid, isCodeValid else { return }

        // 检查是否匹配 mock 账号
        if let mockAccount = mockAccounts.first(where: { $0.phone == phoneNumber && $0.code == verificationCode }) {
            loginManager.login(phone: phoneNumber, name: mockAccount.name)
            dismiss()
            return
        }

        isLoading = true

        // 调用后端登录接口
        APIService.shared.login(
            phone: phoneNumber,
            code: verificationCode,
            captchaId: captchaId,
            captchaCode: captchaCode
        ) { [self] result in
            isLoading = false

            switch result {
            case .success(let response):
                if let loginResult = response.data {
                    APIConfig.authToken = loginResult.token
                    loginManager.login(
                        phone: loginResult.phone,
                        name: loginResult.nickname ?? "",
                        userId: loginResult.userId
                    )
                    dismiss()
                }
            case .failure(let error):
                errorMessage = "登录失败: \(error.localizedDescription)"
                showError = true
                refreshCaptcha()
            }
        }
    }
}
