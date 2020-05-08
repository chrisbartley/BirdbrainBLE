//
// Created by Chris Bartley on 4/14/20.
//

import Foundation

public protocol BLECentralManager {
   var delegate: BLECentralManagerDelegate? { get set }
   func startScanning(timeoutSecs: TimeInterval) -> Bool
   func startScanning(timeoutSecs: TimeInterval, allowDuplicates: Bool) -> Bool
   func stopScanning() -> Bool
   func connectToPeripheral(havingUUID uuid: UUID) -> Bool
   func disconnectFromPeripheral(havingUUID uuid: UUID) -> Bool
}
