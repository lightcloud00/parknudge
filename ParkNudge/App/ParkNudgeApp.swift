import SwiftData
import SwiftUI

@main
struct ParkNudgeApp: App {
    private let container: ModelContainer
    private let uiTestColorScheme: ColorScheme?
    @StateObject private var model: AppModel

    init() {
        uiTestColorScheme = UITestAppearance.colorScheme(
            arguments: ProcessInfo.processInfo.arguments
        )
        do {
            let environment = try AppEnvironment.make()
            container = environment.container
            _model = StateObject(wrappedValue: environment.model)
        } catch {
            fatalError("ParkNudge could not initialize local storage: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(model)
                .preferredColorScheme(uiTestColorScheme)
                .task { await model.bootstrap() }
        }
        .modelContainer(container)
    }
}
