import SwiftUI

@MainActor
struct NotchView: View {
    var body: some View {
        UnevenRoundedRectangle(bottomLeadingRadius: 10, bottomTrailingRadius: 10, style: .continuous)
            .fill(.black)
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}
