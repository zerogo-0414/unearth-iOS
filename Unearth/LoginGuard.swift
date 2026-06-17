//
//  LoginGuard.swift
//  Unearth
//
//  Created by Theo on 2026/6/9.
//

import SwiftUI

// MARK: - 登录守卫
struct LoginGuard {
    /// 检查是否已登录，未登录则显示登录提示
    static func check(
        isLoggedIn: Bool,
        showLogin: Binding<Bool>,
        action: @escaping () -> Void
    ) {
        if isLoggedIn {
            action()
        } else {
            showLogin.wrappedValue = true
        }
    }

    /// 检查是否已登录，未登录则显示自定义提示
    static func checkWithAlert(
        isLoggedIn: Bool,
        showAlert: Binding<Bool>,
        action: @escaping () -> Void
    ) {
        if isLoggedIn {
            action()
        } else {
            showAlert.wrappedValue = true
        }
    }
}

// MARK: - 登录提示视图
struct LoginRequiredAlert: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var showLogin: Bool
    let message: String

    func body(content: Content) -> some View {
        content.alert("需要登录", isPresented: $isPresented) {
            Button("去登录") {
                showLogin = true
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(message)
        }
    }
}

extension View {
    func loginRequiredAlert(
        isPresented: Binding<Bool>,
        showLogin: Binding<Bool>,
        message: String = "请先登录后再进行此操作"
    ) -> some View {
        modifier(LoginRequiredAlert(
            isPresented: isPresented,
            showLogin: showLogin,
            message: message
        ))
    }
}
