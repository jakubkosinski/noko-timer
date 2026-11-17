import XCTest
import ServiceManagement
@testable import NokoBar

private final class FakeLoginItem: LoginItemService {
    var status: SMAppService.Status = .notRegistered
    var shouldThrow = false
    var registerCalls = 0
    var unregisterCalls = 0
    struct Failure: Error {}

    func register() throws {
        registerCalls += 1
        if shouldThrow { throw Failure() }
        status = .enabled
    }
    func unregister() throws {
        unregisterCalls += 1
        if shouldThrow { throw Failure() }
        status = .notRegistered
    }
}

@MainActor
final class LaunchAtLoginTests: XCTestCase {
    func testEnableRegisters() {
        let fake = FakeLoginItem()
        let l = LaunchAtLogin(service: fake)
        XCTAssertFalse(l.isEnabled)
        l.setEnabled(true)
        XCTAssertEqual(fake.registerCalls, 1)
        XCTAssertTrue(l.isEnabled)
        XCTAssertNil(l.errorMessage)
    }

    func testDisableUnregisters() {
        let fake = FakeLoginItem()
        fake.status = .enabled
        let l = LaunchAtLogin(service: fake)
        XCTAssertTrue(l.isEnabled)
        l.setEnabled(false)
        XCTAssertEqual(fake.unregisterCalls, 1)
        XCTAssertFalse(l.isEnabled)
    }

    func testRegisterFailureSetsErrorAndStaysOff() {
        let fake = FakeLoginItem()
        fake.shouldThrow = true
        let l = LaunchAtLogin(service: fake)
        l.setEnabled(true)
        XCTAssertNotNil(l.errorMessage)
        XCTAssertFalse(l.isEnabled)
    }

    func testRequiresApproval() {
        let fake = FakeLoginItem()
        fake.status = .requiresApproval
        let l = LaunchAtLogin(service: fake)
        XCTAssertTrue(l.requiresApproval)
        XCTAssertFalse(l.isEnabled)
    }

    func testRefreshPicksUpExternalChange() {
        let fake = FakeLoginItem()
        let l = LaunchAtLogin(service: fake)
        fake.status = .enabled
        l.refresh()
        XCTAssertTrue(l.isEnabled)
    }
}
