import XCTest
import CoreBluetooth
@testable import BirdbrainBLE

final class BLETests: XCTestCase {
   private let bogusDeviceUUID = UUID.init(uuidString: "ABCDEFAB-CDEF-ABCD-EFAB-CDEFABCDEFAB")!

   let ledOnCommand: [UInt8] = [0xE0,
                                0xFF, 0x00, 0x00, /* ones */
                                0x00, 0xFF, 0x00, /* tens */
                                0x00, 0x00, 0xFF  /* hundreds */]
   let ledOffCommand: [UInt8] = [0xE0,
                                 0x00, 0x00, 0x00, /* ones */
                                 0x00, 0x00, 0x00, /* tens */
                                 0x00, 0x00, 0x00  /* hundreds */]
   let startNotificationsCommand: [UInt8] = [0x62, 0x67]
   let stopNotificationsCommand: [UInt8] = [0x62, 0x73]

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

   func testInit() {
      XCTAssertNotNil(StandardBLECentralManager(servicesAndCharacteristics: BogusServicesAndCharacteristics.instance))
      XCTAssertNotNil(StandardBLECentralManager(servicesAndCharacteristics: BLEUARTServicesAndCharacteristics.instance,
                                                delegate: NoOpBLECentralManagerDelegate()))
   }

   func testScanTimeout() {
      let delegate: ScanTimeoutDelegate = ScanTimeoutDelegate(self)
      let centralManager = StandardBLECentralManager(servicesAndCharacteristics: BogusServicesAndCharacteristics.instance,
                                                     delegate: delegate)

      // Wait for the powered on expectation to be fulfilled, or time out after 5 seconds
      print("Waiting for BLE state to switch to powered on...")
      delegate.waitForPoweredOnExpectation()

      print("Scanning...")
      XCTAssertTrue(centralManager.startScanning(timeoutSecs: 2.0), "Expected startScanning() to return true")
      // Wait for the scan timeout expectation to be fulfilled, or time out after 5 seconds
      delegate.waitForScanTimeoutExpectation()
      XCTAssertTrue(true)
   }

   func testScanWhenAlreadyScanning() {
      let delegate: ScanTimeoutDelegate = ScanTimeoutDelegate(self)
      delegate.invertScanTimeoutExpectation()
      let centralManager = StandardBLECentralManager(servicesAndCharacteristics: BogusServicesAndCharacteristics.instance,
                                                     delegate: delegate)

      // Wait for the powered on expectation to be fulfilled, or time out after 5 seconds
      print("Waiting for BLE state to switch to powered on...")
      delegate.waitForPoweredOnExpectation()

      print("Scanning for up to 5 seconds...")
      XCTAssertTrue(centralManager.startScanning(timeoutSecs: 5.0), "Expected startScanning() to return true")

      // sleep for a second
      print("Sleeping for 1 second...")
      do {
         sleep(1)
      }

      print("Call startScanning() again, to make sure it returns false since we're already scanning")
      XCTAssertFalse(centralManager.startScanning(timeoutSecs: 5.0), "Expected startScanning() to return false since it should already be scanning")

      print("Call stopScanning()")
      XCTAssertTrue(centralManager.stopScanning(), "Stopping the scan should return true")
      print("Call stopScanning() again, to make sure it returns false since we're not scanning")
      XCTAssertFalse(centralManager.stopScanning(), "Stopping the scan again should return false")

      delegate.waitForScanTimeoutExpectation()
      XCTAssertTrue(true)
   }

   func testScanDiscoverSuccessForBirdbrainBLEUARTPeripheral() {
      let delegate = ScanDiscoverSuccessDelegate(self)
      let centralManager: BLECentralManager = StandardBLECentralManager(servicesAndCharacteristics: BLEUARTServicesAndCharacteristics.instance,
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

   func testScanRediscoverSuccessForBirdbrainBLEUARTPeripheral() {
      let delegate = ScanRediscoverSuccessDelegate(self)
      let centralManager: BLECentralManager = StandardBLECentralManager(servicesAndCharacteristics: BLEUARTServicesAndCharacteristics.instance,
                                                                        delegate: delegate)

      // Wait for the powered on expectation to be fulfilled, or timeout after 5 seconds
      print("Waiting for BLE state to switch to powered on...")
      delegate.waitForPoweredOnExpectation()

      print("Scanning...")
      if centralManager.startScanning(timeoutSecs: 45) {
         print("Waiting for up to 30 seconds for scan to succeed and a device to be rediscovered")
         delegate.waitForScanRediscoverSuccessExpectation(timeout: 30)
         XCTAssertTrue(centralManager.stopScanning())
         // Wait for the scan timeout expectation to be fulfilled, or timeout after 5 seconds
         delegate.waitForScanTimeoutExpectation(timeout: 5)
         XCTAssertTrue(true)
      }
      else {
         XCTFail("Scanning should have started")
      }
   }

   func testConnectToNonExistentPeripheral() {
      let delegate = PoweredOnBLEDelegate(self)
      let centralManager = StandardBLECentralManager(servicesAndCharacteristics: BLEUARTServicesAndCharacteristics.instance,
                                                     delegate: delegate)

      // Wait for the powered on expectation to be fulfilled, or timeout after 5 seconds
      print("Waiting for BLE state to switch to powered on...")
      delegate.waitForPoweredOnExpectation()

      XCTAssertFalse(centralManager.connectToPeripheral(havingUUID: bogusDeviceUUID))
   }

   func testDisonnectFromNonExistentPeripheral() {
      let delegate = PoweredOnBLEDelegate(self)
      let centralManager = StandardBLECentralManager(servicesAndCharacteristics: BLEUARTServicesAndCharacteristics.instance,
                                                     delegate: delegate)

      // Wait for the powered on expectation to be fulfilled, or timeout after 5 seconds
      print("Waiting for BLE state to switch to powered on...")
      delegate.waitForPoweredOnExpectation()

      XCTAssertFalse(centralManager.disconnectFromPeripheral(havingUUID: bogusDeviceUUID))
   }

   func testConnectToBirdbrainBLEUARTPeripheralSuccess() {
      let delegate = ConnectDisconnectSuccessDelegate(self)
      let centralManager = StandardBLECentralManager(servicesAndCharacteristics: BLEUARTServicesAndCharacteristics.instance,
                                                     delegate: delegate)

      // Wait for the powered on expectation to be fulfilled, or timeout after 5 seconds
      print("Waiting for BLE state to switch to powered on...")
      delegate.waitForPoweredOnExpectation()

      print("Scanning...")
      if centralManager.startScanning(timeoutSecs: 5.0) {
         print("Waiting for up to 5 seconds for scan to succeed")
         // Wait for the scan timeout expectation to be fulfilled, or timeout after 5 seconds
         delegate.waitForScanDiscoverSuccessExpectation()
         XCTAssertTrue(centralManager.stopScanning())

         delegate.waitForScanTimeoutExpectation()
         XCTAssertTrue(true)

         if let uuid = delegate.discoveredPeripheralUUID {
            print("In peripheralDiscoveredCallback, now trying to connect (plus 2 additional to check redundant connection attempts)")
            XCTAssertTrue(centralManager.connectToPeripheral(havingUUID: uuid))
            XCTAssertFalse(centralManager.connectToPeripheral(havingUUID: uuid), "Redundant connect while connecting should return false")
            delegate.waitForConnectSuccessExpectation()
            XCTAssertFalse(centralManager.connectToPeripheral(havingUUID: uuid), "Redundant connect while connected should return false")

            // sleep for a second
            print("Sleeping for 10 seconds...")
            do {
               sleep(10)
            }

            // now disconnect
            print("Now try to disconnect (plus 2 additional to check redundant disconnection attempts)")
            XCTAssertTrue(centralManager.disconnectFromPeripheral(havingUUID: uuid))
            XCTAssertFalse(centralManager.disconnectFromPeripheral(havingUUID: uuid), "Redundant disconnect while disconnecting should return false")
            delegate.waitForDisconnectSuccessExpectation()
            XCTAssertFalse(centralManager.disconnectFromPeripheral(havingUUID: uuid), "Redundant disconnect while disconnected should return false")
         }
         else {
            XCTFail("No discovered peripheral!")
         }
      }
      else {
         XCTFail("Scanning should have started")
      }
   }

   private func runTestsOnConnectedPeripheral(additionalTestsTimeout: TimeInterval = 5, _ additionalTests: (BLEPeripheral, XCTestExpectation) -> Void) {
      let delegate = ConnectDisconnectSuccessDelegate(self)
      let centralManager = StandardBLECentralManager(servicesAndCharacteristics: BLEUARTServicesAndCharacteristics.instance,
                                                     delegate: delegate)

      // Wait for the powered on expectation to be fulfilled, or timeout after 5 seconds
      print("Waiting for BLE state to switch to powered on...")
      delegate.waitForPoweredOnExpectation()

      print("Scanning...")
      if centralManager.startScanning(timeoutSecs: 5.0) {
         print("Waiting for up to 5 seconds for scan to succeed")
         // Wait for the scan timeout expectation to be fulfilled, or timeout after 5 seconds
         delegate.waitForScanDiscoverSuccessExpectation()
         XCTAssertTrue(centralManager.stopScanning())

         delegate.waitForScanTimeoutExpectation()
         XCTAssertTrue(true)

         if let uuid = delegate.discoveredPeripheralUUID {
            print("In peripheralDiscoveredCallback, now trying to connect")
            XCTAssertTrue(centralManager.connectToPeripheral(havingUUID: uuid))

            print("BEGIN WAITING FOR connectSuccessExpectation \(Date().timeIntervalSince1970)")
            delegate.waitForConnectSuccessExpectation()
            print("END WAITING FOR connectSuccessExpectation \(Date().timeIntervalSince1970)")

            if let connectedPeripheral = delegate.connectedPeripheral {
               print("[\(Date().timeIntervalSince1970)]: Start running tests...")
               let additionalTestsDoneExpectation = expectation(description: "Additional tests are done")
               additionalTests(connectedPeripheral, additionalTestsDoneExpectation)
               print("[\(Date().timeIntervalSince1970)]: Waiting for additional tests to complete...")
               wait(for: [additionalTestsDoneExpectation], timeout: additionalTestsTimeout)
               print("[\(Date().timeIntervalSince1970)]: Done running additional tests!")

               print("[\(Date().timeIntervalSince1970)]: Now try to disconnect")
               XCTAssertTrue(centralManager.disconnectFromPeripheral(havingUUID: uuid))
               delegate.waitForDisconnectSuccessExpectation()
               XCTAssertTrue(true)
            }
            else {
               XCTFail("No connected peripheral!")
            }
         }
         else {
            XCTFail("No discovered peripheral!")
         }
      }
      else {
         XCTFail("Scanning should have started")
      }
   }

   func testIsPropertySupported() {
      runTestsOnConnectedPeripheral(additionalTestsTimeout: 0) { (peripheral, testsDoneExpectation) in
         print("Checking the various properties of the RX characteristic...")
         let rx = BLEUARTServicesAndCharacteristics.rxUUID
         XCTAssertFalse(peripheral.isPropertySupported(property: .broadcast, byCharacteristic: rx), "Property 'broadcast' should not be supported")
         XCTAssertFalse(peripheral.isPropertySupported(property: .read, byCharacteristic: rx), "Property 'read' should not be supported")
         XCTAssertFalse(peripheral.isPropertySupported(property: .writeWithoutResponse, byCharacteristic: rx), "Property 'writeWithoutResponse' should not be supported")
         XCTAssertFalse(peripheral.isPropertySupported(property: .write, byCharacteristic: rx), "Property 'write' should not be supported")
         XCTAssertTrue(peripheral.isPropertySupported(property: .notify, byCharacteristic: rx), "Property 'notify' should be supported")
         XCTAssertFalse(peripheral.isPropertySupported(property: .indicate, byCharacteristic: rx), "Property 'indicate' should not be supported")
         XCTAssertFalse(peripheral.isPropertySupported(property: .authenticatedSignedWrites, byCharacteristic: rx), "Property 'authenticatedSignedWrites' should not be supported")
         XCTAssertFalse(peripheral.isPropertySupported(property: .extendedProperties, byCharacteristic: rx), "Property 'extendedProperties' should not be supported")
         XCTAssertFalse(peripheral.isPropertySupported(property: .notifyEncryptionRequired, byCharacteristic: rx), "Property 'notifyEncryptionRequired' should not be supported")
         XCTAssertFalse(peripheral.isPropertySupported(property: .indicateEncryptionRequired, byCharacteristic: rx), "Property 'indicateEncryptionRequired' should not be supported")

         print("Checking the various properties of the TX characteristic...")
         let tx = BLEUARTServicesAndCharacteristics.txUUID
         XCTAssertFalse(peripheral.isPropertySupported(property: .broadcast, byCharacteristic: tx), "Property 'broadcast' should not be supported")
         XCTAssertFalse(peripheral.isPropertySupported(property: .read, byCharacteristic: tx), "Property 'read' should not be supported")
         XCTAssertTrue(peripheral.isPropertySupported(property: .writeWithoutResponse, byCharacteristic: tx), "Property 'writeWithoutResponse' should be supported")
         XCTAssertTrue(peripheral.isPropertySupported(property: .write, byCharacteristic: tx), "Property 'write' should be supported")
         XCTAssertFalse(peripheral.isPropertySupported(property: .notify, byCharacteristic: tx), "Property 'notify' should not be supported")
         XCTAssertFalse(peripheral.isPropertySupported(property: .indicate, byCharacteristic: tx), "Property 'indicate' should not be supported")
         XCTAssertFalse(peripheral.isPropertySupported(property: .authenticatedSignedWrites, byCharacteristic: tx), "Property 'authenticatedSignedWrites' should not be supported")
         XCTAssertFalse(peripheral.isPropertySupported(property: .extendedProperties, byCharacteristic: tx), "Property 'extendedProperties' should not be supported")
         XCTAssertFalse(peripheral.isPropertySupported(property: .notifyEncryptionRequired, byCharacteristic: tx), "Property 'notifyEncryptionRequired' should not be supported")
         XCTAssertFalse(peripheral.isPropertySupported(property: .indicateEncryptionRequired, byCharacteristic: tx), "Property 'indicateEncryptionRequired' should not be supported")

         print("Checking the read property of a bogus characteristic...")
         XCTAssertFalse(peripheral.isPropertySupported(property: CBCharacteristicProperties.read, byCharacteristic: BogusServicesAndCharacteristics.char1UUID), "Property 'read' should not be supported by a nonexistent characteristic")

         testsDoneExpectation.fulfill()
      }
   }

   func testWriteBySettingCubeTowerLEDs() {
      runTestsOnConnectedPeripheral(additionalTestsTimeout: 5) { (peripheral, testsDoneExpectation) in
         print("Set the LEDs to blue, green, red and blink them 5 times")

         for n in 1...10 {
            XCTAssertTrue(peripheral.writeWithoutResponse(bytes: (n % 2 == 0 ? ledOnCommand : ledOffCommand), toCharacteristic: BLEUARTServicesAndCharacteristics.txUUID))
            do {
               sleep(1)
            }
         }

         testsDoneExpectation.fulfill()
      }
   }

   func testCubeTowerRxNotify() {

      runTestsOnConnectedPeripheral(additionalTestsTimeout: 5) { (peripheral, testsDoneExpectation) in

         class TestPeripheralDelegate: BLEPeripheralDelegate {
            let didEnableNotifying: () -> Void
            let didWriteFirstValue: () -> Void
            let didWriteSecondValue: () -> Void
            let didDisableNotifying: (Bool) -> Void

            var numValuesWritten = 0
            var didReceiveUpdates = false

            init(didEnableNotifying: @escaping () -> Void,
                 didWriteFirstValue: @escaping () -> Void,
                 didWriteSecondValue: @escaping () -> Void,
                 didDisableNotifying: @escaping (Bool) -> Void) {
               self.didEnableNotifying = didEnableNotifying
               self.didWriteFirstValue = didWriteFirstValue
               self.didWriteSecondValue = didWriteSecondValue
               self.didDisableNotifying = didDisableNotifying
            }

            func blePeripheral(_ peripheral: BLEPeripheral, didUpdateNotificationStateFor characteristicUUID: CBUUID, isNotifying: Bool, error: Error?) {
               if let error = error {
                  print("TestPeripheralDelegate.didUpdateNotificationStateFor(\(peripheral)|\(characteristicUUID)|isNotifying=\(isNotifying)|error=\(error))")
               }
               else {
                  print("TestPeripheralDelegate.didUpdateNotificationStateFor(\(peripheral)|\(characteristicUUID)|isNotifying=\(isNotifying))")
                  if (isNotifying) {
                     didEnableNotifying()
                  }
                  else {
                     didDisableNotifying(didReceiveUpdates)
                  }
               }
            }

            func blePeripheral(_ peripheral: BLEPeripheral, didWriteValueFor characteristicUUID: CBUUID, error: Error?) {
               if let error = error {
                  print("TestPeripheralDelegate.didWriteValueFor(\(peripheral)|\(characteristicUUID)|error=\(error))")
               }
               else {
                  print("TestPeripheralDelegate.didWriteValueFor(\(peripheral)|\(characteristicUUID)")
                  numValuesWritten += 1
                  if numValuesWritten == 1 {
                     didWriteFirstValue()
                  }
                  else {
                     didWriteSecondValue()
                  }
               }
            }

            func blePeripheral(_ peripheral: BLEPeripheral, didUpdateValueFor characteristicUUID: CBUUID, value: Data?, error: Error?) {
               if let error = error {
                  print("TestPeripheralDelegate.didUpdateValueFor(\(peripheral)|\(characteristicUUID)|error=\(error))")
               }
               else {
                  if let value = value {
                     didReceiveUpdates = true
                     print("TestPeripheralDelegate.didUpdateValueFor(\(peripheral)|\(characteristicUUID)|value=\(Array(value)))")
                  }
                  else {
                     print("TestPeripheralDelegate.didUpdateValueFor(\(peripheral)|\(characteristicUUID)|value=[nil]")
                  }
               }
            }
         }

         let promise = expectation(description: "Notifications turned on and then back off")
         peripheral.delegate = TestPeripheralDelegate(
               didEnableNotifying: {
                  // tell the peripheral to start notifying
                  print("[\(Date().timeIntervalSince1970)]: sending startNotificationsCommand")
                  XCTAssertTrue(peripheral.writeWithResponse(bytes: self.startNotificationsCommand, toCharacteristic: BLEUARTServicesAndCharacteristics.txUUID))
               },
               didWriteFirstValue: {
                  sleep(1)

                  // tell the peripheral to stop notifying
                  print("[\(Date().timeIntervalSince1970)]: sending stopNotificationsCommand")
                  XCTAssertTrue(peripheral.writeWithResponse(bytes: self.stopNotificationsCommand, toCharacteristic: BLEUARTServicesAndCharacteristics.txUUID))
               },
               didWriteSecondValue: {
                  // disable
                  print("[\(Date().timeIntervalSince1970)]: calling setNotifyDisabled()")
                  XCTAssertTrue(peripheral.setNotifyDisabled(onCharacteristic: BLEUARTServicesAndCharacteristics.rxUUID))
               },
               didDisableNotifying: { didReceiveUpdates in
                  if didReceiveUpdates {
                     promise.fulfill()
                  }
                  else {
                     XCTFail("No value updates received!")
                  }
               })

         // first need to enable notifications
         print("[\(Date().timeIntervalSince1970)]: calling setNotifyEnabled()")
         XCTAssertTrue(peripheral.setNotifyEnabled(onCharacteristic: BLEUARTServicesAndCharacteristics.rxUUID))

         print("[\(Date().timeIntervalSince1970)]: waiting for notification enable/disable dance to complete")
         wait(for: [promise], timeout: 2)

         print("[\(Date().timeIntervalSince1970)]: Waiting 1 second before fulfilling the testsDoneExpectation so I can watch the callbacks")
         DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
            print("[\(Date().timeIntervalSince1970)]: Calling testsDoneExpectation.fulfill()")
            testsDoneExpectation.fulfill()
         })
      }
   }

   static var allTests = [
      ("testLinuxTestSuiteIncludesAllTests", testLinuxTestSuiteIncludesAllTests),
      ("testInit", testInit),
      ("testScanTimeout", testScanTimeout),
      ("testScanWhenAlreadyScanning", testScanWhenAlreadyScanning),
      ("testScanDiscoverSuccessForBirdbrainBLEUARTPeripheral", testScanDiscoverSuccessForBirdbrainBLEUARTPeripheral),
      ("testScanRediscoverSuccessForBirdbrainBLEUARTPeripheral", testScanRediscoverSuccessForBirdbrainBLEUARTPeripheral),
      ("testConnectToNonExistentPeripheral", testConnectToNonExistentPeripheral),
      ("testDisonnectFromNonExistentPeripheral", testDisonnectFromNonExistentPeripheral),
      ("testConnectToBirdbrainBLEUARTPeripheralSuccess", testConnectToBirdbrainBLEUARTPeripheralSuccess),
      ("testIsPropertySupported", testIsPropertySupported),
      ("testWriteBySettingCubeTowerLEDs", testWriteBySettingCubeTowerLEDs),
      ("testCubeTowerRxNotify", testCubeTowerRxNotify),
   ]
}
