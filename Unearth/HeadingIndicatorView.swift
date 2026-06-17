//
//  HeadingIndicatorView.swift
//  Unearth
//
//  Created by Theo on 2026/6/9.
//

import SwiftUI

// MARK: - 自定义朝向指示器
struct HeadingIndicatorView: View {
    let heading: Double  // 0-360度

    var body: some View {
        ZStack {
            // 外圈（当前位置圆点）
            Circle()
                .fill(Color.green.opacity(0.3))
                .frame(width: 30, height: 30)

            // 内圈（实心绿点）
            Circle()
                .fill(Color.green)
                .frame(width: 14, height: 14)

            // 朝向锥形区域
            ConeShape()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.green.opacity(0.6),
                            Color.green.opacity(0.1)
                        ]),
                        startPoint: .center,
                        endPoint: .top
                    )
                )
                .frame(width: 40, height: 60)
                .offset(y: -45)  // 向上偏移
                .rotationEffect(.degrees(heading))
        }
        .frame(width: 80, height: 80)
    }
}

// MARK: - 锥形形状
struct ConeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        // 从底部中心开始
        path.move(to: CGPoint(x: width / 2, y: height))

        // 左侧弧线
        path.addQuadCurve(
            to: CGPoint(x: 0, y: 0),
            control: CGPoint(x: width * 0.1, y: height * 0.3)
        )

        // 顶部弧线
        path.addQuadCurve(
            to: CGPoint(x: width, y: 0),
            control: CGPoint(x: width / 2, y: -height * 0.1)
        )

        // 右侧弧线
        path.addQuadCurve(
            to: CGPoint(x: width / 2, y: height),
            control: CGPoint(x: width * 0.9, y: height * 0.3)
        )

        path.closeSubpath()
        return path
    }
}

#Preview {
    ZStack {
        Color.gray
        HeadingIndicatorView(heading: 45)
    }
}
