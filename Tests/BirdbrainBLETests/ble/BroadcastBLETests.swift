import XCTest
import CoreBluetooth
@testable import BirdbrainBLE

class BroadcastDeviceServicesAndCharacteristics: SupportedServicesAndCharacteristics {
   public static let instance = BroadcastDeviceServicesAndCharacteristics()

   public static let serviceUUID = CBUUID(string: "42610000-7274-6c65-7946-656174686572")

   private static let serviceAndCharacteristicUUIDs: [CBUUID : [CBUUID]] = [serviceUUID : []]

   public var serviceUUIDs: [CBUUID] {
      Array(BroadcastDeviceServicesAndCharacteristics.serviceAndCharacteristicUUIDs.keys)
   }

   public func characteristicUUIDs(belongingToService service: CBService) -> [CBUUID]? {
      BroadcastDeviceServicesAndCharacteristics.serviceAndCharacteristicUUIDs[service.uuid]
   }

   private init() {}
}

class PoweredOnBroadcastBLEDelegate: BroadcastBLECentralManagerDelegate {
   let testCase: XCTestCase
   let poweredOnExpectation: XCTestExpectation

   init(_ testCase: XCTestCase) {
      self.testCase = testCase
      self.poweredOnExpectation = testCase.expectation(description: "BLE powered on")
   }

   func didUpdateState(to state: CBManagerState) {
      print("Delegate received didUpdateState(\(state))")
   }

   func didPowerOn() {
      print("Delegate received didPowerOn")
      poweredOnExpectation.fulfill()
   }

   func didPowerOff() {
      print("Delegate received didPowerOff")
   }

   func didScanTimeout() {
      print("Delegate received didScanTimeout")
   }

   func didDiscoverPeripheral(uuid: UUID, advertisementData: [String : Any], rssi: NSNumber, isRediscovery: Bool) {
      print("Delegate received didDiscoverPeripheral [\(uuid)] with RSSI [\(rssi)], isRediscovery=[\(isRediscovery)].  Advertisement data contains:")
      for (key, val) in advertisementData {
         print("   [\(key)]:[\(val)]")
      }
   }

   func didPeripheralDisappear(uuid: UUID) {
      print("Delegate received didPeripheralDisappear(\(uuid))")
   }

   func waitForPoweredOnExpectation(timeout: TimeInterval = 5) {
      testCase.wait(for: [poweredOnExpectation], timeout: timeout)
   }
}

class BroadcastScanTimeoutDelegate: PoweredOnBroadcastBLEDelegate {
   var scanTimeoutExpectation: XCTestExpectation

   override init(_ testCase: XCTestCase) {
      self.scanTimeoutExpectation = testCase.expectation(description: "BLE scan timed out. Do you have an appropriate broadcast BLE device running?")
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

class BroadcastScanDiscoverSuccessDelegate: BroadcastScanTimeoutDelegate {
   private let scanDiscoverSuccessExpectation: XCTestExpectation

   override init(_ testCase: XCTestCase) {
      self.scanDiscoverSuccessExpectation = testCase.expectation(description: "BLE scan succeeded")
      self.scanDiscoverSuccessExpectation.assertForOverFulfill = false
      super.init(testCase)
      invertScanTimeoutExpectation()
   }

   override func didDiscoverPeripheral(uuid: UUID, advertisementData: [String : Any], rssi: NSNumber, isRediscovery: Bool) {
      super.didDiscoverPeripheral(uuid: uuid, advertisementData: advertisementData, rssi: rssi, isRediscovery: isRediscovery)

      // don't fulfill until we get a rediscovery
      if isRediscovery {
         scanDiscoverSuccessExpectation.fulfill()
      }
   }

   func waitForScanDiscoverSuccessExpectation(timeout: TimeInterval = 5) {
      testCase.wait(for: [scanDiscoverSuccessExpectation], timeout: timeout)
   }
}

class BroadcastPeripheralDisappearedDelegate: PoweredOnBroadcastBLEDelegate {
   private let expectation: XCTestExpectation

   private var discoveredPeripherals = Set<UUID>()

   override init(_ testCase: XCTestCase) {
      self.expectation = testCase.expectation(description: "Peripheral disappeared")
      self.expectation.assertForOverFulfill = false
      super.init(testCase)
   }

   override func didDiscoverPeripheral(uuid: UUID, advertisementData: [String : Any], rssi: NSNumber, isRediscovery: Bool) {
      discoveredPeripherals.insert(uuid)
      print("Delegate received didDiscoverPeripheral [\(uuid)] (total discovered: \(discoveredPeripherals.count))")
   }

   override func didPeripheralDisappear(uuid: UUID) {
      discoveredPeripherals.remove(uuid)
      print("Delegate received didPeripheralDisappear [\(uuid)] (total remaining: \(discoveredPeripherals.count))")
      if discoveredPeripherals.isEmpty {
         print("All discovered peripherals have disappeared.  All done!")
         expectation.fulfill()
      }
   }

   func waitForPeripheralDisappearedExpectation(timeout: TimeInterval = 5) {
      testCase.wait(for: [expectation], timeout: timeout)
   }
}

final class BroadcastBLETests: XCTestCase {

   // See https://oleb.net/blog/2017/03/keeping-xctest-in-sync/
   func testLinuxTestSuiteIncludesAllTests() {
      #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
         let thisClass = type(of: self)
         let linuxCount = thisClass.allTests.count
         #if swift(>=4.0)
            let darwinCount = thisClass.defaultTestSuite.testCaseCount
         #else
            let darwinCount = Int(thisClass.defaultTestSuite().testCaseCount)
         #endif
         XCTAssertEqual(linuxCount, darwinCount, "\(darwinCount - linuxCount) tests are missing from allTests")
      #endif
   }

   func testScanDiscoverSuccess() {
      let delegate = BroadcastScanDiscoverSuccessDelegate(self)
      let centralManager = StandardBroadcastBLECentralManager(servicesAndCharacteristics: BroadcastDeviceServicesAndCharacteristics.instance,
                                                              delegate: delegate)

      // Wait for the powered on expectation to be fulfilled, or timeout after 5 seconds
      print("Waiting for BLE state to switch to powered on...")
      delegate.waitForPoweredOnExpectation()

      print("Scanning...")
      if centralManager.startScanning(timeoutSecs: 5.0) {
         print("Waiting for up to 5 seconds for scan to succeed")
         delegate.waitForScanDiscoverSuccessExpectation()
         XCTAssertTrue(centralManager.stopScanning())
         // Wait for the scan timeout expectation to be fulfilled, or timeout after 5 seconds
         delegate.waitForScanTimeoutExpectation()
         XCTAssertTrue(true)
      }
      else {
         XCTFail("Scanning should have started")
      }
   }

   func testPeripheralDisappeared() {
      let delegate = BroadcastPeripheralDisappearedDelegate(self)

      let centralManager = StandardBroadcastBLECentralManager(servicesAndCharacteristics: BroadcastDeviceServicesAndCharacteristics.instance,
                                                              delegate: delegate)

      // Wait for the powered on expectation to be fulfilled, or time out after 5 seconds
      print("Waiting for BLE state to switch to powered on...")
      delegate.waitForPoweredOnExpectation()

      print("Scanning...")
      print("ACTION REQUIRED: Turn on one or more broadcast BLE devices, then turn them all off (in any order) to verify handling of peripheral disappearance.")
      XCTAssertTrue(centralManager.startScanning(timeoutSecs: 600.0, assumeDisappearanceAfter: 5.0), "Expected startScanning() to return true")

      // Wait for the scan timeout expectation to be fulfilled, or time out after 5 seconds
      delegate.waitForPeripheralDisappearedExpectation(timeout: 600.0)
      centralManager.stopScanning()
      centralManager.delegate = nil
      XCTAssertTrue(true)
   }

   static var allTests = [
      ("testLinuxTestSuiteIncludesAllTests", testLinuxTestSuiteIncludesAllTests),
      ("testScanDiscoverSuccess", testScanDiscoverSuccess),
      ("testPeripheralDisappeared", testPeripheralDisappeared),
   ]
}
