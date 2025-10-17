import SwiftUI
import TallyCore

/// Colors and measurements shared by the views.
public enum Theme {
    /// Client dots, chosen to stay distinct from each other in light and dark mode.
    static let clientColors: [Color] = [
        Color(red: 0.13, green: 0.55, blue: 0.50),
        Color(red: 0.85, green: 0.45, blue: 0.20),
        Color(red: 0.36, green: 0.42, blue: 0.82),
        Color(red: 0.78, green: 0.30, blue: 0.47),
        Color(red: 0.55, green: 0.50, blue: 0.15),
        Color(red: 0.25, green: 0.55, blue: 0.80),
        Color(red: 0.55, green: 0.35, blue: 0.70),
        Color(red: 0.40, green: 0.58, blue: 0.30)
    ]

    static let accent = Color(red: 0.13, green: 0.55, blue: 0.50)

    static func color(for client: Client) -> Color {
        clientColors[abs(client.colorIndex) % clientColors.count]
    }

    public static let panelWidth: CGFloat = 320
}

/// The small colored circle that identifies a client.
struct ClientDot: View {
    let client: Client

    var body: some View {
        Circle()
            .fill(Theme.color(for: client))
            .frame(width: 9, height: 9)
    }
}
