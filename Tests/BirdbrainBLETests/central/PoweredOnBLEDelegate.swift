import XCTest
@testable import BirdbrainBLE

class PoweredOnBLEDelegate: NoOpBLECentralManagerDelegate {
   let testCase: XCTestCase
   let poweredOnExpectation: XCTestExpectation

   init(_ testCase: XCTestCase) {
      self.testCase = testCase
      self.poweredOnExpectation = testCase.expectation(description: "BLE powered on")
   }

   override func didPowerOn() {
      print("Delegate received didPowerOn")
      poweredOnExpectation.fulfill()
   }

   func waitForPoweredOnExpectation(timeout: TimeInterval = 5) {
      testCase.wait(for: [poweredOnExpectation], timeout: timeout)
   }
}
