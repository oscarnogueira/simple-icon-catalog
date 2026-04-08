import XCTest
@testable import IconViewer

@MainActor
final class IconCatalogViewModelTests: XCTestCase {
    func testFilterByName() {
        let vm = IconCatalogViewModel()
        vm.allIcons = [
            IconItem(fileURL: URL(fileURLWithPath: "/tmp/arrow-left.svg"),
                     contentHash: "a", width: 24, height: 24),
            IconItem(fileURL: URL(fileURLWithPath: "/tmp/arrow-right.svg"),
                     contentHash: "b", width: 24, height: 24),
            IconItem(fileURL: URL(fileURLWithPath: "/tmp/circle.svg"),
                     contentHash: "c", width: 24, height: 24),
        ]

        vm.searchText = "arrow"

        XCTAssertEqual(vm.filteredIcons.count, 2)
        XCTAssertTrue(vm.filteredIcons.allSatisfy { $0.displayName.contains("arrow") })
    }

    func testEmptyFilterShowsAll() {
        let vm = IconCatalogViewModel()
        vm.allIcons = [
            IconItem(fileURL: URL(fileURLWithPath: "/tmp/a.svg"),
                     contentHash: "a", width: 24, height: 24),
            IconItem(fileURL: URL(fileURLWithPath: "/tmp/b.svg"),
                     contentHash: "b", width: 24, height: 24),
        ]

        vm.searchText = ""

        XCTAssertEqual(vm.filteredIcons.count, 2)
    }

    func testQuarantinedIconsExcludedFromFiltered() {
        let vm = IconCatalogViewModel()
        vm.allIcons = [
            IconItem(fileURL: URL(fileURLWithPath: "/tmp/good.svg"),
                     contentHash: "a", width: 24, height: 24),
            IconItem(fileURL: URL(fileURLWithPath: "/tmp/bad.svg"),
                     contentHash: "b", width: 4096, height: 4096,
                     quarantineReason: .tooLarge),
        ]

        XCTAssertEqual(vm.filteredIcons.count, 1)
        XCTAssertEqual(vm.filteredIcons.first?.displayName, "good")
    }

    func testQuarantinedIconsList() {
        let vm = IconCatalogViewModel()
        vm.allIcons = [
            IconItem(fileURL: URL(fileURLWithPath: "/tmp/good.svg"),
                     contentHash: "a", width: 24, height: 24),
            IconItem(fileURL: URL(fileURLWithPath: "/tmp/bad.svg"),
                     contentHash: "b", width: 4096, height: 4096,
                     quarantineReason: .tooLarge),
        ]

        XCTAssertEqual(vm.quarantinedIcons.count, 1)
        XCTAssertEqual(vm.quarantinedIcons.first?.displayName, "bad")
    }
}
