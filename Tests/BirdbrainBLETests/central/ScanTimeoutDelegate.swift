import XCTest
@testable import BirdbrainBLE

class ScanTimeoutDelegate: PoweredOnBLEDelegate {
   var scanTimeoutExpectation: XCTestExpectation

   override init(_ testCase: XCTestCase) {
      self.scanTimeoutExpectation = testCase.expectation(description: "BLE scan timed out. Do you have a Birdbrain BLE UART device running?")
      super.init(testCase)
   }

   override func didScanTimeout() {
      print("Delegate received didScanTimeout")
      scanTimeoutExpectation.fulfill()
   }

   func invertScanTimeoutExpectation() {
      scanTimeoutExpectation.isInverted = true
   }

   func waitForScanTimeoutExpectation(timeout: TimeInterval = 5) {
      testCase.wait(for: [scanTimeoutExpectation], timeout: timeout)
   }
}
