//
// Created by Chris Bartley on 5/6/20.
//

import Foundation
import CoreBluetooth

public class UARTDeviceServicesAndCharacteristics: SupportedServicesAndCharacteristics {
   public static let instance = UARTDeviceServicesAndCharacteristics()

   public static let serviceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
   public static let txUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
   public static let rxUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")

   private static let serviceAndCharacteristicUUIDs: [CBUUID : [CBUUID]] = [serviceUUID : [txUUID, rxUUID]]

   public var serviceUUIDs: [CBUUID] {
      Array(UARTDeviceServicesAndCharacteristics.serviceAndCharacteristicUUIDs.keys)
   }

   public func characteristicUUIDs(belongingToService service: CBService) -> [CBUUID]? {
      UARTDeviceServicesAndCharacteristics.serviceAndCharacteristicUUIDs[service.uuid]
   }

   private init() {}
}
