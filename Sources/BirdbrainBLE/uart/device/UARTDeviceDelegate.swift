//
// Created by Chris Bartley on 4/28/20.
//

import Foundation

public protocol UARTDeviceDelegate {
   func uartDevice(_ device: UARTDevice, isSendingStateChangeNotifications: Bool)
   func uartDevice(_ device: UARTDevice, newState state: Data)
   func uartDevice(_ device: UARTDevice, errorGettingState error: Error)
}