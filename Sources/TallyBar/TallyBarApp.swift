import SwiftUI
import TallyUI

@main
struct TallyBarApp: App {
    @StateObject private var controller = AppController.live()

    var body: some Scene {
        MenuBarExtra {
            MenuPanel(model: controller.model, actions: controller.menuActions)
        } label: {
            MenuBarLabel(model: controller.model)
        }
        .menuBarExtraStyle(.window)
    }
}
