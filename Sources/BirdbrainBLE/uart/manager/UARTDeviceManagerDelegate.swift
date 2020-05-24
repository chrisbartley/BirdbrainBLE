//
// Created by Chris Bartley on 4/24/20.
//

import Foundation

public protocol UARTDeviceManagerDelegate {
   func didUpdateState(to state: UARTDeviceManagerState)
   func didDiscover(uuid: UUID, advertisementSignature: AdvertisementSignature?, advertisementData: [String : Any], rssi: NSNumber)
   func didRediscover(uuid: UUID, advertisementSignature: AdvertisementSignature?, advertisementData: [String : Any], rssi: NSNumber)
   func didConnectTo(uuid: UUID)
   func didDisconnectFrom(uuid: UUID, error: Error?)
   func didFailToConnectTo(uuid: UUID, error: Error?)
}