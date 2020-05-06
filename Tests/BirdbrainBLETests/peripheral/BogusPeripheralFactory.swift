import Foundation
import CoreBluetooth
@testable import BirdbrainBLE

class BogusPeripheralFactory: BLEPeripheralFactory {
   static let instance = BogusPeripheralFactory()

   static let serviceUUID = CBUUID(string: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")
   static let char1UUID = CBUUID(string: "AAAAAAA1-BBBB-CCCC-DDDD-EEEEEEEEEEEE")
   static let char2UUID = CBUUID(string: "AAAAAAA2-BBBB-CCCC-DDDD-EEEEEEEEEEEE")
   static let char3UUID = CBUUID(string: "AAAAAAA3-BBBB-CCCC-DDDD-EEEEEEEEEEEE")

   private static let serviceAndCharacteristicUUIDs: [CBUUID : [CBUUID]] = [serviceUUID : [char1UUID, char2UUID, char3UUID]]

   var serviceUUIDs: [CBUUID] {
      Array(BogusPeripheralFactory.serviceAndCharacteristicUUIDs.keys)
   }

   func characteristicUUIDs(belongingToService service: CBService) -> [CBUUID]? {
      BogusPeripheralFactory.serviceAndCharacteristicUUIDs[service.uuid]
   }

   private init() {}

   func create(peripheral: CBPeripheral, advertisementData: [String : Any]) -> BLEPeripheral {
      StandardBLEPeripheral(peripheral: peripheral, advertisementData: advertisementData)
   }
}
