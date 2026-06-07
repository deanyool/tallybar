import SwiftUI
import TallyCore
import TallyUI

/// The app icon: the goal ring on a deep green tile. Rendered at 512 points, which gives
/// a 1024 pixel PNG on a Retina screen, for `scripts/make-icon.sh`.
struct AppIconArt: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 112, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.10, green: 0.42, blue: 0.38), Color(red: 0.06, green: 0.26, blue: 0.25)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .padding(46)
            Circle()
                .stroke(Color.white.opacity(0.18), lineWidth: 44)
                .frame(width: 270, height: 270)
            Circle()
                .trim(from: 0, to: 0.72)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 44, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 270, height: 270)
        }
        .frame(width: 512, height: 512)
    }
}
