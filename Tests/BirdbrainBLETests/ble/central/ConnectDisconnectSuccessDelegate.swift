import XCTest
@testable import BirdbrainBLE

class ConnectDisconnectSuccessDelegate: ScanDiscoverSuccessDelegate {
   private let connectSuccessExpectation: XCTestExpectation
   private let disconnectSuccessExpectation: XCTestExpectation

   var discoveredPeripheralUUID: UUID?
   var connectedPeripheral: BLEPeripheral?

   override init(_ testCase: XCTestCase) {
      self.connectSuccessExpectation = testCase.expectation(description: "BLE connect succeeded")
      self.disconnectSuccessExpectation = testCase.expectation(description: "BLE disconnect succeeded")
      super.init(testCase)
   }

   override func waitForScanDiscoverSuccessExpectation(timeout: TimeInterval = 5) {
      super.waitForScanDiscoverSuccessExpectation(timeout: timeout)
   }

   override func didDiscoverPeripheral(uuid: UUID, advertisementData: [String : Any], rssi: NSNumber) {
      discoveredPeripheralUUID = uuid
      super.didDiscoverPeripheral(uuid: uuid, advertisementData: advertisementData, rssi: rssi)
   }

   override func didConnectToPeripheral(peripheral: BLEPeripheral) {
      print("Delegate received didConnectToPeripheral(\(peripheral.uuid))")
      connectedPeripheral = peripheral
      connectSuccessExpectation.fulfill()
   }

   override func didDisconnectFromPeripheral(uuid: UUID, error: Error?) {
      print("Delegate received didDisconnectFromPeripheral(uuid: \(uuid), error: \(String(describing: error)))")
      disconnectSuccessExpectation.fulfill()
   }

   func waitForConnectSuccessExpectation(timeout: TimeInterval = 5) {
      testCase.wait(for: [connectSuccessExpectation], timeout: timeout)
   }

   func waitForDisconnectSuccessExpectation(timeout: TimeInterval = 5) {
      testCase.wait(for: [disconnectSuccessExpectation], timeout: timeout)
   }
}
