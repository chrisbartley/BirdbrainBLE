import XCTest
@testable import BirdbrainBLE

class ScanRediscoverSuccessDelegate: ScanTimeoutDelegate {
   private let scanRediscoverSuccessExpectation: XCTestExpectation
   private var wasRediscovered = false

   override init(_ testCase: XCTestCase) {
      self.scanRediscoverSuccessExpectation = testCase.expectation(description: "BLE scan succeeded")
      super.init(testCase)
      invertScanTimeoutExpectation()
   }

   override func didDiscoverPeripheral(uuid: UUID, advertisementData: [String : Any], rssi: NSNumber) {
      print("Delegate received didDiscoverPeripheral [\(uuid)] with RSSI [\(rssi)]")
   }

   override func didRediscoverPeripheral(uuid: UUID, advertisementData: [String : Any], rssi: NSNumber) {
      print("Delegate received didRediscoverPeripheral [\(uuid)] with RSSI [\(rssi)]")

      // ensure we don't fulfill the expectation more than once
      if !wasRediscovered {
         wasRediscovered = true
         scanRediscoverSuccessExpectation.fulfill()
      }
   }

   func waitForScanRediscoverSuccessExpectation(timeout: TimeInterval = 5) {
      testCase.wait(for: [scanRediscoverSuccessExpectation], timeout: timeout)
   }
}