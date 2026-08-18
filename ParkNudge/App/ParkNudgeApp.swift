import SwiftData
import SwiftUI

@main
struct ParkNudgeApp: App {
    private let container: ModelContainer
    @StateObject private var model: AppModel

    init() {
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
                .task { await model.bootstrap() }
        }
        .modelContainer(container)
    }
}
