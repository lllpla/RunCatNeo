/*
 LineGraphView.swift
 UserInterface

 Created by Takuto Nakamura on 2026/05/09.
 Copyright 2026 Kyome22 (Takuto Nakamura)

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import AppKit
import SwiftUI

struct LineGraphView: View {
    var values: [Double]

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                path.move(to: CGPoint(x: 0, y: height))
                if values.count > 1 {
                    let step = width / CGFloat(values.count - 1)
                    values.enumerated().forEach { offset, value in
                        let v = min(100, max(2, value))
                        path.addLine(to: CGPoint(x: step * CGFloat(offset), y: height - 0.16 * v))
                    }
                }
                path.addLine(to: CGPoint(x: width, y: height))
                path.closeSubpath()
            }
            .fill(Color(nsColor: .controlAccentColor))
        }
        .frame(height: 16)
        .frame(maxWidth: .infinity)
    }
}
