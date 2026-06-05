import AppKit

@main
struct SpacesRenamerMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()

        app.delegate = delegate
        app.run()
    }
}
