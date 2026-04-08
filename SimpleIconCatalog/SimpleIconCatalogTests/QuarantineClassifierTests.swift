import XCTest
@testable import IconViewer

final class QuarantineClassifierTests: XCTestCase {
    let classifier = QuarantineClassifier()

    func testAcceptsNormalIcon() {
        let result = classifier.classify(width: 64, height: 64)
        XCTAssertNil(result)
    }

    func testQuarantinesTooLarge() {
        let result = classifier.classify(width: 2048, height: 2048)
        XCTAssertEqual(result, .tooLarge)
    }

    func testQuarantinesTooSmall() {
        let result = classifier.classify(width: 8, height: 8)
        XCTAssertEqual(result, .tooSmall)
    }

    func testQuarantinesBadAspectRatio() {
        let result = classifier.classify(width: 500, height: 100)
        XCTAssertEqual(result, .badAspectRatio)
    }

    func testAcceptsBorderlineDimensions() {
        XCTAssertNil(classifier.classify(width: 1024, height: 1024))
        XCTAssertNil(classifier.classify(width: 16, height: 16))
    }

    func testAcceptsSlightlyNonSquare() {
        XCTAssertNil(classifier.classify(width: 150, height: 100))
    }
}
