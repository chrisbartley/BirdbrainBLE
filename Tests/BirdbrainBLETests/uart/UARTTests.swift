import XCTest
import CoreBluetooth
@testable import BirdbrainBLE

fileprivate class ConnectDisconnectDeviceManagerDelegate: UARTDeviceManagerDelegate {

   private let testCase: XCTestCase
   private let enabledExpectation: XCTestExpectation
   private let scanDiscoverSuccessExpectation: XCTestExpectation
   private let connectSuccessExpectation: XCTestExpectation
   private let disconnectSuccessExpectation: XCTestExpectation

   var discoveredUUID: UUID?
   var connectedUUID: UUID?

   init(_ testCase: XCTestCase) {
      self.testCase = testCase
      self.enabledExpectation = testCase.expectation(description: "UART Device Manager enabled")
      self.scanDiscoverSuccessExpectation = testCase.expectation(description: "UART Device Manager scan succeeded")
      self.connectSuccessExpectation = testCase.expectation(description: "UART Device Manager connect succeeded")
      self.disconnectSuccessExpectation = testCase.expectation(description: "UART Device Manager disconnect succeeded")
   }

   func didUpdateState(to state: UARTDeviceManagerState) {
      print("Delegate received didUpdateState(\(state))")
      if state == .enabled {
         enabledExpectation.fulfill()
      }
   }

   func didScanTimeout() {
      XCTFail("Delegate received didScanTimeout()!")
   }

   func didDiscover(uuid: UUID, name: String?, advertisedName: String?, advertisementData: [String : Any], rssi: Foundation.NSNumber) {
      print("Delegate received didDiscover(uuid=\(uuid),name=\(String(describing: name)),advertisedName=\(String(describing: advertisedName))")
      discoveredUUID = uuid
      scanDiscoverSuccessExpectation.fulfill()
   }

   func didRediscover(uuid: UUID, name: String?, advertisedName: String?, advertisementData: [String : Any], rssi: Foundation.NSNumber) {
      print("Delegate received didRediscover(uuid=\(uuid),name=\(String(describing: name)),advertisedName=\(String(describing: advertisedName))")
   }

   func didConnectTo(uuid: UUID) {
      print("Delegate received didConnectTo(\(uuid)))")
      connectedUUID = uuid
      connectSuccessExpectation.fulfill()
   }

   func didDisconnectFrom(uuid: UUID, error: Error?) {
      print("Delegate received didDisconnectFrom(\(uuid)))")
      disconnectSuccessExpectation.fulfill()
   }

   func didFailToConnectTo(uuid: UUID, error: Error?) {
      XCTFail("Delegate received didFailToConnectTo(\(uuid)))")
   }

   func waitForEnabledExpectation(timeout: TimeInterval = 5) {
      testCase.wait(for: [enabledExpectation], timeout: timeout)
   }

   func waitForScanDiscoverSuccessExpectation(timeout: TimeInterval = 5) {
      testCase.wait(for: [scanDiscoverSuccessExpectation], timeout: timeout)
   }

   func waitForConnectSuccessExpectation(timeout: TimeInterval = 5) {
      testCase.wait(for: [connectSuccessExpectation], timeout: timeout)
   }

   func waitForDisconnectSuccessExpectation(timeout: TimeInterval = 5) {
      testCase.wait(for: [disconnectSuccessExpectation], timeout: timeout)
   }
}

fileprivate class AllowAllScanFilter: UARTDeviceScanFilter {
   static public let instance = AllowAllScanFilter()

   public func isOfType(uuid: UUID, advertisementData: [String : Any], rssi: NSNumber) -> Bool {
      return true
   }

   private init() {}
}

final class UARTTests: XCTestCase {

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

   private func runCubeTowerTests(additionalTestsTimeout: TimeInterval = 5, _ additionalTests: (CubeTower, XCTestExpectation) -> Void) {

      let delegate = ConnectDisconnectDeviceManagerDelegate(self)
      let deviceManager = UARTDeviceManager<CubeTower>(scanFilter: AllowAllScanFilter.instance, delegate: delegate)

      // Wait for the enabled expectation to be fulfilled, or timeout after 5 seconds
      print("Waiting for UARTDeviceManager to be enabled...")
      delegate.waitForEnabledExpectation()

      print("Scanning...")
      if deviceManager.startScanning() {
         delegate.waitForScanDiscoverSuccessExpectation()
         XCTAssertTrue(deviceManager.stopScanning())

         if let discoveredUUID = delegate.discoveredUUID {
            print("Try to connect to UART \(discoveredUUID)")
            XCTAssertTrue(deviceManager.connectToDevice(havingUUID: discoveredUUID))
            delegate.waitForConnectSuccessExpectation()

            if let connectedUUID = delegate.connectedUUID {
               if let uart = deviceManager.getDevice(uuid: connectedUUID) {
                  print("Connected to UART \(uart.uuid)")
                  print("[\(Date().timeIntervalSince1970)]: Start running tests...")
                  let additionalTestsDoneExpectation = expectation(description: "Additional tests are done")
                  additionalTests(uart, additionalTestsDoneExpectation)
                  print("[\(Date().timeIntervalSince1970)]: Waiting for additional tests to complete...")
                  wait(for: [additionalTestsDoneExpectation], timeout: additionalTestsTimeout)
                  print("[\(Date().timeIntervalSince1970)]: Done running additional tests!")

                  print("[\(Date().timeIntervalSince1970)]: Disconnecting from UART \(uart.uuid)")
                  XCTAssertTrue(deviceManager.disconnectFromDevice(havingUUID: uart.uuid))
                  delegate.waitForDisconnectSuccessExpectation()
                  XCTAssertTrue(true)
               }
               else {
                  XCTFail("No connected UART!")
               }
            }
            else {
               XCTFail("No connected UUID!")
            }
         }
         else {
            XCTFail("No discovered UART!")
         }
      }
      else {
         XCTFail("Scanning should have started")
      }
   }

   func testCubeTowerConnectDisconnectSuccess() {
      runCubeTowerTests(additionalTestsTimeout: 0) { (cubeTower, testsDoneExpectation) in
         testsDoneExpectation.fulfill()
      }
   }

   func testCubeTowerStateUpdateSuccess() {
      runCubeTowerTests(additionalTestsTimeout: 5) { (cubeTower, testsDoneExpectation) in
         XCTAssertTrue(cubeTower.startStateChangeNotifications())

         DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
            XCTAssertTrue(cubeTower.stopStateChangeNotifications())
            XCTAssertNotNil(cubeTower.rawState)
            print("[\(Date().timeIntervalSince1970)]: Calling testsDoneExpectation.fulfill()")
            testsDoneExpectation.fulfill()
         })
      }
   }

   func testCubeTowerSetLEDsSuccess() {
      runCubeTowerTests(additionalTestsTimeout: 10) { (cubeTower, testsDoneExpectation) in

         let red = 0xFF0000
         let green = 0x00FF00
         let blue = 0x0000FF

         cubeTower.setLEDs(left: red, middle: green, right: blue)
         sleep(1)
         cubeTower.setLEDs(left: blue, middle: red, right: green)
         sleep(1)
         cubeTower.setLEDs(left: green, middle: blue, right: red)
         sleep(1)
         cubeTower.turnLEDsOff()
         sleep(1)

         DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
            print("[\(Date().timeIntervalSince1970)]: Calling testsDoneExpectation.fulfill()")
            testsDoneExpectation.fulfill()
         })
      }
   }

   func testDeviceNameGenerator() {
      let name1 = (advertised: "CTCF2C3", expected: "Singing Scarlet Tiger")
      let name2 = (advertised: "CTC0D80", expected: "Intrepid Copper Slug")
      let name3 = (advertised: "GBD521C", expected: "Creative Lime Bee")
      let name4 = (advertised: "GB932CA", expected: "Spikey Titanium Seahorse")
      let name5 = (advertised: "728E4", expected: "Thorny Plum Lion")
      XCTAssertEqual(UARTDeviceNameGenerator.instance.generateNameFrom(advertisedName: name1.advertised), name1.expected)
      XCTAssertEqual(UARTDeviceNameGenerator.instance.generateNameFrom(advertisedName: name2.advertised), name2.expected)
      XCTAssertEqual(UARTDeviceNameGenerator.instance.generateNameFrom(advertisedName: name3.advertised), name3.expected)
      XCTAssertEqual(UARTDeviceNameGenerator.instance.generateNameFrom(advertisedName: name4.advertised), name4.expected)
      XCTAssertEqual(UARTDeviceNameGenerator.instance.generateNameFrom(advertisedName: name5.advertised), name5.expected)
      XCTAssertNil(UARTDeviceNameGenerator.instance.generateNameFrom(advertisedName: ""))
      XCTAssertNil(UARTDeviceNameGenerator.instance.generateNameFrom(advertisedName: "FFFF"))
      XCTAssertNil(UARTDeviceNameGenerator.instance.generateNameFrom(advertisedName: "   0D80"))
      XCTAssertNil(UARTDeviceNameGenerator.instance.generateNameFrom(advertisedName: "0D80   "))
      XCTAssertNil(UARTDeviceNameGenerator.instance.generateNameFrom(advertisedName: "   0D80   "))
      XCTAssertNil(UARTDeviceNameGenerator.instance.generateNameFrom(advertisedName: "Z890F"))
   }

   func testAdvertisedNamePrefixScanFilter() {
      let uuid = UUID.init(uuidString: "ABCDEFAB-CDEF-ABCD-EFAB-CDEFABCDEFAB")!
      let rssi = NSNumber(42)

      let ctFilter = AdvertisedNamePrefixScanFilter(prefix: "CT")
      XCTAssertTrue(ctFilter.isOfType(uuid: uuid, advertisementData: [CBAdvertisementDataLocalNameKey : "CT"], rssi: rssi))
      XCTAssertTrue(ctFilter.isOfType(uuid: uuid, advertisementData: [CBAdvertisementDataLocalNameKey : "CT12345"], rssi: rssi))
      XCTAssertFalse(ctFilter.isOfType(uuid: uuid, advertisementData: [CBAdvertisementDataLocalNameKey : "ct12345"], rssi: rssi))
      XCTAssertFalse(ctFilter.isOfType(uuid: uuid, advertisementData: [CBAdvertisementDataLocalNameKey : "ct"], rssi: rssi))
      XCTAssertFalse(ctFilter.isOfType(uuid: uuid, advertisementData: [CBAdvertisementDataLocalNameKey : "CC12345"], rssi: rssi))
      XCTAssertFalse(ctFilter.isOfType(uuid: uuid, advertisementData: [CBAdvertisementDataLocalNameKey : ""], rssi: rssi))
      XCTAssertFalse(ctFilter.isOfType(uuid: uuid, advertisementData: [CBAdvertisementDataLocalNameKey : " CT"], rssi: rssi))
      XCTAssertFalse(ctFilter.isOfType(uuid: uuid, advertisementData: [CBAdvertisementDataLocalNameKey : " ct"], rssi: rssi))
      XCTAssertFalse(ctFilter.isOfType(uuid: uuid, advertisementData: [:], rssi: rssi))

      let ctFilterCaseInsentive = AdvertisedNamePrefixScanFilter(prefix: "CT", isCaseSensitive: false)
      XCTAssertTrue(ctFilterCaseInsentive.isOfType(uuid: uuid, advertisementData: [CBAdvertisementDataLocalNameKey : "CT12345"], rssi: rssi))
      XCTAssertTrue(ctFilterCaseInsentive.isOfType(uuid: uuid, advertisementData: [CBAdvertisementDataLocalNameKey : "ct12345"], rssi: rssi))
      XCTAssertTrue(ctFilterCaseInsentive.isOfType(uuid: uuid, advertisementData: [CBAdvertisementDataLocalNameKey : "CT"], rssi: rssi))
      XCTAssertTrue(ctFilterCaseInsentive.isOfType(uuid: uuid, advertisementData: [CBAdvertisementDataLocalNameKey : "ct"], rssi: rssi))
      XCTAssertFalse(ctFilterCaseInsentive.isOfType(uuid: uuid, advertisementData: [CBAdvertisementDataLocalNameKey : "CC12345"], rssi: rssi))
      XCTAssertFalse(ctFilterCaseInsentive.isOfType(uuid: uuid, advertisementData: [CBAdvertisementDataLocalNameKey : ""], rssi: rssi))
      XCTAssertFalse(ctFilterCaseInsentive.isOfType(uuid: uuid, advertisementData: [CBAdvertisementDataLocalNameKey : " CT"], rssi: rssi))
      XCTAssertFalse(ctFilterCaseInsentive.isOfType(uuid: uuid, advertisementData: [CBAdvertisementDataLocalNameKey : " ct"], rssi: rssi))
      XCTAssertFalse(ctFilterCaseInsentive.isOfType(uuid: uuid, advertisementData: [:], rssi: rssi))

      let allowAllFilter = AdvertisedNamePrefixScanFilter(prefix: "")
      XCTAssertTrue(allowAllFilter.isOfType(uuid: uuid, advertisementData: [CBAdvertisementDataLocalNameKey : "CT12345"], rssi: rssi))
      XCTAssertTrue(allowAllFilter.isOfType(uuid: uuid, advertisementData: [CBAdvertisementDataLocalNameKey : "ct12345"], rssi: rssi))
      XCTAssertTrue(allowAllFilter.isOfType(uuid: uuid, advertisementData: [CBAdvertisementDataLocalNameKey : "CC12345"], rssi: rssi))
      XCTAssertTrue(allowAllFilter.isOfType(uuid: uuid, advertisementData: [CBAdvertisementDataLocalNameKey : "CT"], rssi: rssi))
      XCTAssertTrue(allowAllFilter.isOfType(uuid: uuid, advertisementData: [CBAdvertisementDataLocalNameKey : "ct"], rssi: rssi))
      XCTAssertTrue(allowAllFilter.isOfType(uuid: uuid, advertisementData: [CBAdvertisementDataLocalNameKey : "CC"], rssi: rssi))
      XCTAssertTrue(allowAllFilter.isOfType(uuid: uuid, advertisementData: [CBAdvertisementDataLocalNameKey : " CT"], rssi: rssi))
      XCTAssertTrue(allowAllFilter.isOfType(uuid: uuid, advertisementData: [CBAdvertisementDataLocalNameKey : " ct"], rssi: rssi))
      XCTAssertFalse(allowAllFilter.isOfType(uuid: uuid, advertisementData: [:], rssi: rssi))
   }

   static var allTests = [
      ("testLinuxTestSuiteIncludesAllTests", testLinuxTestSuiteIncludesAllTests),
      ("testCubeTowerConnectDisconnectSuccess", testCubeTowerConnectDisconnectSuccess),
      ("testCubeTowerStateUpdateSuccess", testCubeTowerStateUpdateSuccess),
      ("testCubeTowerSetLEDsSuccess", testCubeTowerSetLEDsSuccess),
      ("testDeviceNameGenerator", testDeviceNameGenerator),
      ("testAdvertisedNamePrefixScanFilter", testAdvertisedNamePrefixScanFilter),
   ]
}
