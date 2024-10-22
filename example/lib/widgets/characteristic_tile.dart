import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import "../utils/snackbar.dart";

import "descriptor_tile.dart";

class CharacteristicTile extends StatefulWidget {
  final BluetoothCharacteristic characteristic;
  final List<DescriptorTile> descriptorTiles;

  const CharacteristicTile({Key? key, required this.characteristic, required this.descriptorTiles}) : super(key: key);

  @override
  State<CharacteristicTile> createState() => _CharacteristicTileState();
}

class _CharacteristicTileState extends State<CharacteristicTile> {
  List<int> _value = [];

  late StreamSubscription<List<int>> _lastValueSubscription;

  @override
  void initState() {
    super.initState();
    _lastValueSubscription = widget.characteristic.lastValueStream.listen((value) {
      _value = value;
      if (_value.length > 0) {
        if (widget.characteristic.characteristicUuid.str == "49535343-4c8a-39b3-2f49-511cff073b7e") {
          print("Notification. uuid = " + widget.characteristic.characteristicUuid.str);
          print("Received value. len = " + _value.length.toString());
          if (_value.length == 5) {
            if (!flowControl) {
              if (_value[0] == 0 && _value[1] == 20) {
                flowControl = true;
              }
            } else {
              print("Update credt. " + _value[4].toString());
            }
          }
        }
      }
      _value.map((i) => i.toRadixString(16)).toList();
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _lastValueSubscription.cancel();
    super.dispose();
  }

  BluetoothCharacteristic get c => widget.characteristic;

  List<int> _getRandomBytes() {
    final math = Random();
    return [math.nextInt(255), math.nextInt(255), math.nextInt(255), math.nextInt(255)];
  }

  Future onReadPressed() async {
    try {
      await c.read();
      Snackbar.show(ABC.c, "Read: Success", success: true);
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Read Error:", e), success: false);
    }
  }

  bool flowControl = false;

  bool SetUARTMode = false;

  Future onWritePressed() async {
    try {
      if (c.characteristicUuid == Guid.fromString("49535343-4C8A-39B3-2F49-511CFF073B7E")) {
        //print("TransparentControlChar: WriteRequest");
        //await c.write(_getRandomBytes(), withoutResponse: c.properties.write);
        if (!flowControl) {
          print("Enable ReliableBurstTransmit");
          await c.write([20], withoutResponse: c.properties.write);
        } else {
          if (!SetUARTMode) {
            print("Set UART mode");
            SetUARTMode = true;
            await c.write([80, 04, 01], withoutResponse: c.properties.write);
          } else {
            print("Enable UART mode");
            await c.write([80, 05, 04, 01], withoutResponse: c.properties.write);
          }
        }
      } else {
        if (c.characteristicUuid == Guid.fromString("49535343-8841-43F4-A8D4-ECBE34729BB3")) {
          print("Write test data:12ab");
          await c.write([0x31, 0x32, 0x61, 0x62], withoutResponse: c.properties.writeWithoutResponse);
        } else {
          await c.write(_getRandomBytes(), withoutResponse: c.properties.writeWithoutResponse);
        }
      }
      //await c.write(_getRandomBytes(), withoutResponse: c.properties.writeWithoutResponse);

      Snackbar.show(ABC.c, "Write: Success", success: true);
      if (c.properties.read) {
        await c.read();
      }
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Write Error:", e), success: false);
    }
  }

  Future onSubscribePressed() async {
    try {
      String op = c.isNotifying == false ? "Subscribe" : "Unubscribe";
      await c.setNotifyValue(c.isNotifying == false);
      Snackbar.show(ABC.c, "$op : Success", success: true);
      if (c.properties.read) {
        await c.read();
      }
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Subscribe Error:", e), success: false);
    }
  }

  Widget buildUuid(BuildContext context) {
    String uuid = '0x${widget.characteristic.uuid.str.toUpperCase()}';
    return Text(uuid, style: TextStyle(fontSize: 13));
  }

  Widget buildValue(BuildContext context) {
    String data = _value.toString();
    return Text(data, style: TextStyle(fontSize: 13, color: Colors.grey));
  }

  Widget buildReadButton(BuildContext context) {
    return TextButton(
        child: Text("Read"),
        onPressed: () async {
          await onReadPressed();
          if (mounted) {
            setState(() {});
          }
        });
  }

  Widget buildWriteButton(BuildContext context) {
    bool withoutResp = widget.characteristic.properties.writeWithoutResponse;
    return TextButton(
        child: Text(withoutResp ? "WriteNoResp" : "Write"),
        onPressed: () async {
          await onWritePressed();
          if (mounted) {
            setState(() {});
          }
        });
  }

  Widget buildSubscribeButton(BuildContext context) {
    bool isNotifying = widget.characteristic.isNotifying;
    return TextButton(
        child: Text(isNotifying ? "Unsubscribe" : "Subscribe"),
        onPressed: () async {
          await onSubscribePressed();
          if (mounted) {
            setState(() {});
          }
        });
  }

  Widget buildButtonRow(BuildContext context) {
    bool read = widget.characteristic.properties.read;
    bool write = widget.characteristic.properties.write;
    bool notify = widget.characteristic.properties.notify;
    bool indicate = widget.characteristic.properties.indicate;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (read) buildReadButton(context),
        if (write) buildWriteButton(context),
        if (notify || indicate) buildSubscribeButton(context),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    String name = "Characteristic";
    if (widget.characteristic.characteristicUuid.str == "49535343-1e4d-4bd9-ba61-23c647249616") {
      name = "MCHP_Transparent_Rx";
    } else if (widget.characteristic.characteristicUuid.str == "49535343-8841-43f4-a8d4-ecbe34729bb3") {
      name = "MCHP_Transparent_Tx";
    } else if (widget.characteristic.characteristicUuid.str == "49535343-4c8a-39b3-2f49-511cff073b7e") {
      name = "MCHP_Transparent_Control";
    }

    return ExpansionTile(
      title: ListTile(
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            //const Text('Characteristic'),
            Text(name),
            buildUuid(context),
            buildValue(context),
          ],
        ),
        subtitle: buildButtonRow(context),
        contentPadding: const EdgeInsets.all(0.0),
      ),
      children: widget.descriptorTiles,
    );
  }
}
