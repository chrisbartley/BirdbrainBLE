import Foundation
import CoreBluetooth
@testable import BirdbrainBLE

class BogusServicesAndCharacteristics: SupportedServicesAndCharacteristics {
   static let instance = BogusServicesAndCharacteristics()

   static let serviceUUID = CBUUID(string: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")
   static let char1UUID = CBUUID(string: "AAAAAAA1-BBBB-CCCC-DDDD-EEEEEEEEEEEE")
   static let char2UUID = CBUUID(string: "AAAAAAA2-BBBB-CCCC-DDDD-EEEEEEEEEEEE")
   static let char3UUID = CBUUID(string: "AAAAAAA3-BBBB-CCCC-DDDD-EEEEEEEEEEEE")

   private static let serviceAndCharacteristicUUIDs: [CBUUID : [CBUUID]] = [serviceUUID : [char1UUID, char2UUID, char3UUID]]

   var serviceUUIDs: [CBUUID] {
      Array(BogusServicesAndCharacteristics.serviceAndCharacteristicUUIDs.keys)
   }

   func characteristicUUIDs(belongingToService service: CBService) -> [CBUUID]? {
      BogusServicesAndCharacteristics.serviceAndCharacteristicUUIDs[service.uuid]
   }

   private init() {}
}
