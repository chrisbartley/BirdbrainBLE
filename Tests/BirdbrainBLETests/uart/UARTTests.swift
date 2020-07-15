import XCTest
import CoreBluetooth
#if canImport(UIKit)
   import UIKit
#endif

@testable import BirdbrainBLE

// Based on https://stackoverflow.com/a/24263296/703200
extension CGColor {
   static func create(red: Int, green: Int, blue: Int, alpha: CGFloat = 1.0) -> CGColor {
      assert(red >= 0 && red <= 255, "Invalid red component")
      assert(green >= 0 && green <= 255, "Invalid green component")
      assert(blue >= 0 && blue <= 255, "Invalid blue component")

      #if os(iOS)
         return UIColor(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: alpha).cgColor
      #else
         return CGColor(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: alpha)
      #endif
   }

   static func create(rgb: Int, alpha: CGFloat = 1.0) -> CGColor {
      return CGColor.create(red: (rgb >> 16) & 0xFF,
                            green: (rgb >> 8) & 0xFF,
                            blue: rgb & 0xFF,
                            alpha: alpha)
   }
}

fileprivate struct Colors {
   static let red = CGColor.create(rgb: 0xFF0000)
   static let green = CGColor.create(rgb: 0x00FF00)
   static let blue = CGColor.create(rgb: 0x0000FF)
   static let yellow = CGColor.create(rgb: 0xFFFF00)
   static let magenta = CGColor.create(rgb: 0xFF00FF)
   static let teal = CGColor.create(rgb: 0x00FFFF)
   static let white = CGColor.create(rgb: 0xFFFFFF)

   private init() {}
}

fileprivate class DisappearDeviceManagerDelegate: UARTDeviceManagerDelegate {
   private let testCase: XCTestCase
   private let enabledExpectation: XCTestExpectation
   private let disappearExpectation: XCTestExpectation

   private var discoveredPeripherals = Set<UUID>()

   init(_ testCase: XCTestCase) {
      self.testCase = testCase
      self.enabledExpectation = testCase.expectation(description: "UART Device Manager enabled")
      self.disappearExpectation = testCase.expectation(description: "Device disappeared")
      self.disappearExpectation.assertForOverFulfill = false
   }

   func didUpdateState(to state: UARTDeviceManagerState) {
      print("DisappearDeviceManagerDelegate: Delegate received didUpdateState(\(state))")
      if state == .enabled {
         enabledExpectation.fulfill()
      }
   }

   func didDiscover(uuid: UUID, advertisementSignature: AdvertisementSignature?, advertisementData: [String : Any], rssi: Foundation.NSNumber) {
      discoveredPeripherals.insert(uuid)
      print("DisappearDeviceManagerDelegate: Delegate received didDiscover(uuid=\(uuid),advertisementSignature=\(String(describing: advertisementSignature))")
   }

   func didDisappear(uuid: UUID) {
      discoveredPeripherals.remove(uuid)
      print("DisappearDeviceManagerDelegate: Delegate received didPeripheralDisappear [\(uuid)] (total remaining: \(discoveredPeripherals.count))")
      if discoveredPeripherals.isEmpty {
         print("All discovered peripherals have disappeared.  All done!")
         disappearExpectation.fulfill()
      }
   }

   func waitForEnabledExpectation(timeout: TimeInterval = 5) {
      testCase.wait(for: [enabledExpectation], timeout: timeout)
   }

   func waitForDisappearExpectation(timeout: TimeInterval = 5) {
      testCase.wait(for: [disappearExpectation], timeout: timeout)
   }
}

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

   func didDiscover(uuid: UUID, advertisementSignature: AdvertisementSignature?, advertisementData: [String : Any], rssi: Foundation.NSNumber) {
      print("Delegate received didDiscover(uuid=\(uuid),advertisementSignature=\(String(describing: advertisementSignature))")
      discoveredUUID = uuid
      scanDiscoverSuccessExpectation.fulfill()
   }

   func didRediscover(uuid: UUID, advertisementSignature: AdvertisementSignature?, advertisementData: [String : Any], rssi: Foundation.NSNumber) {
      print("Delegate received didRediscover(uuid=\(uuid),advertisementSignature=\(String(describing: advertisementSignature))")
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
      let deviceManager = UARTDeviceManager<CubeTower>(scanFilter: AdvertisedNamePrefixScanFilter(prefix: "CT"), delegate: delegate)

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

   func testCubeTowerDisappearanceSuccess() {
      let delegate = DisappearDeviceManagerDelegate(self)
      let deviceManager = UARTDeviceManager<CubeTower>(scanFilter: AdvertisedNamePrefixScanFilter(prefix: "CT"), delegate: delegate)

      // Wait for the enabled expectation to be fulfilled, or timeout after 5 seconds
      print("Waiting for UARTDeviceManager to be enabled...")
      delegate.waitForEnabledExpectation()

      print("Scanning...")
      print("ACTION REQUIRED: Turn on one or more CubeTower devices, then turn them all off (in any order) to verify handling of peripheral disappearance.")
      XCTAssertTrue(deviceManager.startScanning(timeoutSecs: 600.0, assumeDisappearanceAfter: 3.0), "Expected startScanning() to return true")

      delegate.waitForDisappearExpectation(timeout: 600.0)
      XCTAssertTrue(deviceManager.stopScanning())
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

   func testAdvertisementSignature() {
      let name1 = (advertised: "CTCF2C3", expected: (memorable: "Singing Scarlet Tiger", device: "CF2C3", colors: (color0: Colors.green, color1: Colors.green, color2: Colors.blue)))
      let name2 = (advertised: "CTC0D80", expected: (memorable: "Intrepid Copper Slug", device: "C0D80", colors: (color0: Colors.green, color1: Colors.white, color2: Colors.white)))
      let name3 = (advertised: "GBD521C", expected: (memorable: "Creative Lime Bee", device: "D521C", colors: (color0: Colors.white, color1: Colors.magenta, color2: Colors.magenta)))
      let name4 = (advertised: "GB932CA", expected: (memorable: "Spikey Titanium Seahorse", device: "932CA", colors: (color0: Colors.green, color1: Colors.green, color2: Colors.green)))
      let name5 = (advertised: "728E4", expected: (memorable: "Thorny Plum Lion", device: "728E4", colors: (color0: Colors.magenta, color1: Colors.teal, color2: Colors.red)))

      let as1 = AdvertisementSignature(advertisedName: name1.advertised)
      let as2 = AdvertisementSignature(advertisedName: name2.advertised)
      let as3 = AdvertisementSignature(advertisedName: name3.advertised)
      let as4 = AdvertisementSignature(advertisedName: name4.advertised)
      let as5 = AdvertisementSignature(advertisedName: name5.advertised)
      XCTAssertNotNil(as1)
      XCTAssertNotNil(as2)
      XCTAssertNotNil(as3)
      XCTAssertNotNil(as4)
      XCTAssertNotNil(as5)
      XCTAssertEqual(as1?.memorableName, name1.expected.memorable)
      XCTAssertEqual(as2?.memorableName, name2.expected.memorable)
      XCTAssertEqual(as3?.memorableName, name3.expected.memorable)
      XCTAssertEqual(as4?.memorableName, name4.expected.memorable)
      XCTAssertEqual(as5?.memorableName, name5.expected.memorable)
      XCTAssertEqual(as1?.deviceName, name1.expected.device)
      XCTAssertEqual(as2?.deviceName, name2.expected.device)
      XCTAssertEqual(as3?.deviceName, name3.expected.device)
      XCTAssertEqual(as4?.deviceName, name4.expected.device)
      XCTAssertEqual(as5?.deviceName, name5.expected.device)
      XCTAssertEqual(as1?.colors.color0, name1.expected.colors.color0)
      XCTAssertEqual(as2?.colors.color0, name2.expected.colors.color0)
      XCTAssertEqual(as3?.colors.color0, name3.expected.colors.color0)
      XCTAssertEqual(as4?.colors.color0, name4.expected.colors.color0)
      XCTAssertEqual(as5?.colors.color0, name5.expected.colors.color0)
      XCTAssertEqual(as1?.colors.color1, name1.expected.colors.color1)
      XCTAssertEqual(as2?.colors.color1, name2.expected.colors.color1)
      XCTAssertEqual(as3?.colors.color1, name3.expected.colors.color1)
      XCTAssertEqual(as4?.colors.color1, name4.expected.colors.color1)
      XCTAssertEqual(as5?.colors.color1, name5.expected.colors.color1)
      XCTAssertEqual(as1?.colors.color2, name1.expected.colors.color2)
      XCTAssertEqual(as2?.colors.color2, name2.expected.colors.color2)
      XCTAssertEqual(as3?.colors.color2, name3.expected.colors.color2)
      XCTAssertEqual(as4?.colors.color2, name4.expected.colors.color2)
      XCTAssertEqual(as5?.colors.color2, name5.expected.colors.color2)
      XCTAssertNil(AdvertisementSignature(advertisedName: ""))
      XCTAssertNil(AdvertisementSignature(advertisedName: "FFFF"))
      XCTAssertNil(AdvertisementSignature(advertisedName: "   0D80"))
      XCTAssertNil(AdvertisementSignature(advertisedName: "0D80   "))
      XCTAssertNil(AdvertisementSignature(advertisedName: "   0D80   "))
      XCTAssertNil(AdvertisementSignature(advertisedName: "Z890F"))
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
      ("testCubeTowerDisappearanceSuccess", testCubeTowerDisappearanceSuccess),
      ("testCubeTowerConnectDisconnectSuccess", testCubeTowerConnectDisconnectSuccess),
      ("testCubeTowerStateUpdateSuccess", testCubeTowerStateUpdateSuccess),
      ("testCubeTowerSetLEDsSuccess", testCubeTowerSetLEDsSuccess),
      ("testAdvertisementSignature", testAdvertisementSignature),
      ("testAdvertisedNamePrefixScanFilter", testAdvertisedNamePrefixScanFilter),
   ]
}
