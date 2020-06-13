import Foundation
import XCTest
@testable import BirdbrainBLE

class PeripheralDisappearedDelegate: PoweredOnBLEDelegate {
   private let expectation: XCTestExpectation

   private var discoveredPeripherals = Set<UUID>()

   override init(_ testCase: XCTestCase) {
      self.expectation = testCase.expectation(description: "Peripheral disappeared")
      self.expectation.assertForOverFulfill = false
      super.init(testCase)
   }

   override func didDiscoverPeripheral(uuid: UUID, advertisementData: [String : Any], rssi: Foundation.NSNumber) {
      discoveredPeripherals.insert(uuid)
      print("Delegate received didDiscoverPeripheral [\(uuid)] (total discovered: \(discoveredPeripherals.count))")
   }

   override func didPeripheralDisappear(uuid: UUID) {
      discoveredPeripherals.remove(uuid)
      print("Delegate received didPeripheralDisappear [\(uuid)] (total remaining: \(discoveredPeripherals.count))")
      if discoveredPeripherals.count == 0 {
         print("All discovered peripherals have disappeared.  All done!")
         expectation.fulfill()
      }
   }

   func waitForPeripheralDisappearedExpectation(timeout: TimeInterval = 5) {
      testCase.wait(for: [expectation], timeout: timeout)
   }
}
