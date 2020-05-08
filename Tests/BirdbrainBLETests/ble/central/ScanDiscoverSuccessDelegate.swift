import XCTest
@testable import BirdbrainBLE

class ScanDiscoverSuccessDelegate: ScanTimeoutDelegate {
   private let scanDiscoverSuccessExpectation: XCTestExpectation

   override init(_ testCase: XCTestCase) {
      self.scanDiscoverSuccessExpectation = testCase.expectation(description: "BLE scan succeeded")
      super.init(testCase)
      invertScanTimeoutExpectation()
   }

   override func didDiscoverPeripheral(uuid: UUID, advertisementData: [String : Any], rssi: NSNumber) {
      print("Delegate received didDiscoverPeripheral [\(uuid)] with RSSI [\(rssi)]")
      scanDiscoverSuccessExpectation.fulfill()
   }

   func waitForScanDiscoverSuccessExpectation(timeout: TimeInterval = 5) {
      testCase.wait(for: [scanDiscoverSuccessExpectation], timeout: timeout)
   }
}
