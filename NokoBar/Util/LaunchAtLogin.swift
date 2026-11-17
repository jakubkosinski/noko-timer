import Foundation
import Observation
import ServiceManagement

protocol LoginItemService {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

extension SMAppService: LoginItemService {}

/// Wraps the system login-item state. macOS is the source of truth: the user can also
/// toggle the item in System Settings → General → Login Items.
@MainActor
@Observable
final class LaunchAtLogin {
    private(set) var isEnabled = false
    private(set) var requiresApproval = false
    private(set) var errorMessage: String?

    private let service: LoginItemService

    init(service: LoginItemService = SMAppService.mainApp) {
        self.service = service
        refresh()
    }

    func refresh() {
        let status = service.status
        isEnabled = status == .enabled
        requiresApproval = status == .requiresApproval
    }

    func setEnabled(_ on: Bool) {
        do {
            if on { try service.register() } else { try service.unregister() }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        refresh()
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
