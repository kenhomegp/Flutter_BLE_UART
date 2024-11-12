import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:collection/collection.dart';

class BleUartTile extends StatefulWidget {
  final BluetoothService service;

  final BluetoothCharacteristic transparentCtrl;
  final BluetoothCharacteristic transparentTx;
  final BluetoothCharacteristic transparentRx;
  
  const BleUartTile({Key? key, required this.service, required this.transparentCtrl, required this.transparentTx, required this.transparentRx}) : super(key: key);

  @override
  State<BleUartTile> createState() => _BleUartTileState();
}

enum bleUARTState { FlowControl, UartEnable, TRP, Complete }

class _BleUartTileState extends State<BleUartTile> {
  List<int> _value = [];
  List<int> _txValue = [];
  List<int> _rxValue = [];
  
  late StreamSubscription<List<int>> _lastCommandSubscription;
  late StreamSubscription<List<int>> _lastTxValueSubscription;
  late StreamSubscription<List<int>> _lastRxValueSubscription;

  var initialState = bleUARTState.FlowControl;

  int _credit = 0x05;

  @override
  void initState() {
    super.initState();

    _lastCommandSubscription = widget.transparentCtrl.lastValueStream.listen((value) {
      _value = value;
      if (_value.length > 0) {
        if (widget.transparentCtrl.characteristicUuid.str == "49535343-4c8a-39b3-2f49-511cff073b7e") {
          //print("Notification. uuid = " + widget.characteristic.characteristicUuid.str);
          print("MCHP_Transparent_Control");
          print("Received value. len = " + _value.length.toString());
          _value.forEach((i) {
            print(i.toString());
          });

          Function eq = const ListEquality().equals;

          if (_value.isNotEmpty) {
            if (eq(_value, [0x80, 0x04, 0x01])) {
              print("80,04,01 command complete. credit= " + _credit.toString());
              initialState = bleUARTState.TRP;
            } else if (eq(_value, [0x80, 0x05, 0x04, 0x01])) {
              print("80,05,04,01 command complete. credit = " + _credit.toString());
              initialState = bleUARTState.Complete;
            }
          }

          if (_value.length == 5 && _value[0] != 0x80) {
            //if (!flowControl) {
            if (initialState == bleUARTState.FlowControl) {
              if (_value[0] == 0 && _value[1] == 20) {
                //flowControl = true;
                _credit = _value[4];
                initialState = bleUARTState.UartEnable;
                print("Initial credit. " + _credit.toString());
              }
            } else {
              print("Handle credit. " + _value[4].toString());
              _credit += _value[4];
              print("Credit = " + _credit.toString());
            }
          }
        }
      }
      //_value.map((i) => i.toRadixString(16)).toList();
      
    });

    _lastTxValueSubscription = widget.transparentTx.lastValueStream.listen((value) {
      _txValue = value;
      if (widget.transparentTx.characteristicUuid.str == "49535343-8841-43f4-a8d4-ecbe34729bb3") {
          print("BleUart_Tx. DidWriteCharacteristic");
      }
    });

    _lastRxValueSubscription = widget.transparentRx.lastValueStream.listen((value) {
      _rxValue = value;
      if (widget.transparentTx.characteristicUuid.str == "49535343-1e4d-4bd9-ba61-23c647249616") {
          print("BleUart_Rx.");
      }
    });

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _lastCommandSubscription.cancel();
    _lastTxValueSubscription.cancel();
    _lastRxValueSubscription.cancel();
    super.dispose();
  }

  Widget buildUuid(BuildContext context) {
    String uuid = '0x${widget.service.uuid.str.toUpperCase()}';
    return Text(uuid, style: TextStyle(fontSize: 13));
  }

  BluetoothCharacteristic get c => widget.transparentCtrl;

  Future onSubscribePressed() async {
    try {
      String op = c.isNotifying == false ? "Subscribe" : "Unubscribe";
      await c.setNotifyValue(c.isNotifying == false);
      //Snackbar.show(ABC.c, "$op : Success", success: true);
      if (c.properties.read) {
        await c.read();
      }
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      //Snackbar.show(ABC.c, prettyException("Subscribe Error:", e), success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isNotifying = c.isNotifying;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const Text('MCHP Transparent Service', style: TextStyle(color: Colors.blue)),
        ListTile(
          title: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text("MCHP_Transparent_Control"),
              Text(widget.transparentCtrl.uuid.str, style: TextStyle(fontSize: 13)),
              Text(_value.toString(), style: TextStyle(fontSize: 13, color: Colors.grey))
            ],
          ),
          subtitle: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(onPressed: () async {
                await onSubscribePressed();
                if (mounted) {
                setState(() {});
                }
              }, 
              child: Text(isNotifying ? "Unsubscribe" : "Subscribe"))
            ]),
          contentPadding: const EdgeInsets.all(0.0),
        ),

      ],
    );
    /*return ListTile(
            title: const Text('Service'),
            subtitle: buildUuid(context),
          );*/      
  }

  final growableList = <int>[];
  int totalWrite = 0;

  void CreateTestFile() {
    int k = 50;
    //k = 834;
    //50,1k.txt
    //834,10k.txt
    //8334,100k.txt
    //41667,500k.txt

    //final growableList = <int>[];

    growableList.clear();

    for (int i = 0; i < k; i++) {
      for (int j = 0; j < (10 - (i + 1).toString().length); j++) {
        growableList.add(48);
      }
      growableList.addAll((i + 1).toString().codeUnits);
      growableList.addAll([0x0d, 0x0a]);
    }

    //return growableList;
  }
}
