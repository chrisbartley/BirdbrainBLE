//
// Created by Chris Bartley on 4/24/20.
//

import Foundation

public protocol UARTDeviceManagerDelegate: AnyObject {
   func didUpdateState(to state: UARTDeviceManagerState)
   func didDiscover(uuid: UUID, advertisementSignature: AdvertisementSignature?, advertisementData: [String : Any], rssi: NSNumber)
   func didRediscover(uuid: UUID, advertisementSignature: AdvertisementSignature?, advertisementData: [String : Any], rssi: NSNumber)

   /// Triggered for discovery or rediscovery of peripherals which don't pass the UARTDeviceScanFilter
   func didIgnoreDiscovery(uuid: UUID, advertisementData: [String : Any], rssi: NSNumber, wasRediscovery: Bool)

   func didDisappear(uuid: UUID)
   func didConnectTo(uuid: UUID)
   func didDisconnectFrom(uuid: UUID, error: Error?)
   func didFailToConnectTo(uuid: UUID, error: Error?)
}

public extension UARTDeviceManagerDelegate {
   func didUpdateState(to state: UARTDeviceManagerState) {}

   func didDiscover(uuid: UUID, advertisementSignature: AdvertisementSignature?, advertisementData: [String : Any], rssi: NSNumber) {}

   func didRediscover(uuid: UUID, advertisementSignature: AdvertisementSignature?, advertisementData: [String : Any], rssi: NSNumber) {}

   func didIgnoreDiscovery(uuid: UUID, advertisementData: [String : Any], rssi: NSNumber, wasRediscovery: Bool) {}

   func didDisappear(uuid: UUID) {}

   func didConnectTo(uuid: UUID) {}

   func didDisconnectFrom(uuid: UUID, error: Error?) {}

   func didFailToConnectTo(uuid: UUID, error: Error?) {}
}