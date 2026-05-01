//
//  OnboardingStepView.swift
//  SelfControl
//
//  Created by Satendra Singh on 01/02/26.
//

import SwiftUI

struct OnboardingStepView: View {
    let step: Int
    let totakSteps: Int = 3
    var body: some View {
        HStack {
            Spacer()

            Text("Step \(step) of \(totakSteps)")
                .font(.title2)

            Spacer()

            PartialProgressBar(progress: Double(step) / Double(totakSteps))
            Spacer()

        }
        .padding()
    }
}

struct PartialProgressBar: View {
    var progress: CGFloat   // value between 0.0 and 1.0
    var height: CGFloat = 12

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                
                // Filled portion
                Capsule()
                    .fill(Color.blue)
                    .frame(width: geometry.size.width * progress)
            }
        }
        .frame(height: height)
    }
}

#Preview {
    OnboardingStepView(step: 1)
}
