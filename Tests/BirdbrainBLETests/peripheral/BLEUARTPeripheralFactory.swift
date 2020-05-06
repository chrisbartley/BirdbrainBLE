import Foundation
import CoreBluetooth
@testable import BirdbrainBLE

public class BLEUARTPeripheralFactory: BLEPeripheralFactory {
   public static let instance = BLEUARTPeripheralFactory()

   public static let serviceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
   public static let txUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
   public static let rxUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")

   private static let serviceAndCharacteristicUUIDs: [CBUUID : [CBUUID]] = [serviceUUID : [txUUID, rxUUID]]

   public var serviceUUIDs: [CBUUID] {
      Array(BLEUARTPeripheralFactory.serviceAndCharacteristicUUIDs.keys)
   }

   public func characteristicUUIDs(belongingToService service: CBService) -> [CBUUID]? {
      BLEUARTPeripheralFactory.serviceAndCharacteristicUUIDs[service.uuid]
   }

   private init() {}

   public func create(peripheral: CBPeripheral, advertisementData: [String : Any]) -> BLEPeripheral {
      StandardBLEPeripheral(peripheral: peripheral, advertisementData: advertisementData)
   }
}
