# BirdbrainBLE

Swift package for a BLE central to communicate with a peripheral.  Includes classes for working with Birdbrain BLE UART devices.

## Implementation Notes

Warning: the `StandardBLECentralManager` class's scanning implementation assumes and requires that a peripheral has an advertising name for it to be "discovered". That is, a discovery message from CoreBluetooth for a UUID we've not seen before which doesn't contain an advertising name will be ignored by `StandardBLECentralManager`.  