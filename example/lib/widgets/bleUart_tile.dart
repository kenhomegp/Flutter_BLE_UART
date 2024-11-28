import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import "../utils/snackbar.dart";

import 'package:collection/collection.dart';

class BleUartTile extends StatefulWidget {
  final BluetoothService service;

  final BluetoothCharacteristic transparentCtrl;
  final BluetoothCharacteristic transparentTx;
  final BluetoothCharacteristic transparentRx;

  const BleUartTile(
      {Key? key,
      required this.service,
      required this.transparentCtrl,
      required this.transparentTx,
      required this.transparentRx})
      : super(key: key);

  @override
  State<BleUartTile> createState() => _BleUartTileState();
}

enum bleUARTState { FlowControl, UartEnable, TRP, Start, Complete }

enum bleUARTMode { UART, LoopBack}

class _BleUartTileState extends State<BleUartTile> {
  List<int> _value = [];
  List<int> _txValue = [];
  List<int> _rxValue = [];

  late StreamSubscription<List<int>> _lastCommandSubscription;
  late StreamSubscription<List<int>> _lastTxValueSubscription;
  late StreamSubscription<List<int>> _lastRxValueSubscription;

  var initialState = bleUARTState.FlowControl;

  var mode = bleUARTMode.LoopBack;

  int _credit = 0x00;

  TextButton autoControlButton  = TextButton(
                onPressed: (){
                  print("Test");
                },
                child: Text('Test'));

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
            if(eq(_value, [0x14])){
              print("0x14 command complete. credit= " + _credit.toString());
            }
            else if ((eq(_value, [0x80, 0x04, 0x01])) || (eq(_value, [0x80, 0x02, 0x01]))) {
              //print("0x80,0x04,0x01 command complete. credit= " + _credit.toString());
              print("BLE UART command complete. credit= " + _credit.toString());
              initialState = bleUARTState.TRP;
              onWritePressed(c);
            } else if (eq(_value, [0x80, 0x05, 0x04, 0x01])) {
              print("0x80,0x05,0x04,0x01 command complete. credit = " + _credit.toString());
              if(mode == bleUARTMode.UART){
                initialState = bleUARTState.Complete;
                onClearBleData();
                Snackbar.show(ABC.c, "UART mode", success: true);
              }
              else{
                initialState = bleUARTState.Start;
                onWritePressed(c);
              }
              //onWritePressed(c);
            }
            else if (eq(_value, [0x80, 0x05, 0x01])) {
              print("0x80,0x05,0x01 command complete. credit = " + _credit.toString());
              initialState = bleUARTState.Complete;
              onClearBleData();
              Snackbar.show(ABC.c, "Loopback mode", success: true);
            }
          }

          if (_value.length == 5 && _value[0] != 0x80) {
            //if (!flowControl) {
            if (initialState == bleUARTState.FlowControl) {
              if (_value[0] == 0 && _value[1] == 0x14) {
                //flowControl = true;
                _credit = _value[4];
                initialState = bleUARTState.UartEnable;
                print("Initial credit. " + _credit.toString());
                onWritePressed(c);
              }
            } else {
              print("Handle credit. " + _value[4].toString());
              var tmp = _credit;
              _credit += _value[4];
              print("Credit = " + _credit.toString());
              if(_credit > 16){ //Chimera
                print("credit error!  > 16");
              }

              _value.clear();
              _value.add(_credit);

              if(tmp == 0){
                Future.delayed(const Duration(milliseconds: 10), (){
                  print("delay 10 ms");
                  if(totalWrite != 0 && totalWrite < growableList.length){
                    print("Credit = 0.Continue. totalWrite = " + totalWrite.toString());
                    splitWrite(e, growableList);
                  }
                });
              }
            }
            if (mounted) {
              setState(() {});
            }
          }
        }
      }
      //_value.map((i) => i.toRadixString(16)).toList();
      //if (mounted) {
      //  setState(() {});
      //}
    });

    //_lastRxValueSubscription = widget.transparentRx.lastValueStream.listen((value) {
    _lastRxValueSubscription = widget.transparentRx.onValueReceived.listen((value) {
      _rxValue += value;
      if (widget.transparentRx.characteristicUuid.str == "49535343-1e4d-4bd9-ba61-23c647249616") {
        print("BleUart_Rx. onValueReceived.len = " + _rxValue.length.toString());
        if (mounted) {
          setState(() {});
        }
      }
    });

    _lastTxValueSubscription = widget.transparentTx.lastValueStream.listen((value) {
      _txValue = value;
      if (widget.transparentTx.characteristicUuid.str == "49535343-8841-43f4-a8d4-ecbe34729bb3") {
        //print(initialState);
        if (initialState == bleUARTState.Complete) {
          print("BleUart_Tx. DidWriteCharacteristic. " + _txValue.length.toString());
          print(totalWrite.toString() + "," + growableList.length.toString());
          if (mounted) {
            setState(() {});
          }
        }
        /*if (initialState == bleUARTState.Complete) {
          int process = (totalWrite/growableList.length) as int;
          print("ble uart = " + process.toString());
        }*/
        /*
        if (initialState == bleUARTState.Complete) {
          _txValue.clear();
          _txValue.add((totalWrite/growableList.length) as int);
        }
        else{
          _txValue = value;
        }*/
      }
      else{
        //_txValue.clear();
      }
    });

    Timer(Duration(seconds: 3), () async{
      print("bleUart initState.delay 3 sec");
      //autoControlButton.onPressed!();
      await onSubscribePressed(c);
      print("control characteristic Subscribe");
      sleep(Duration(seconds:1));
      await onSubscribePressed(d);
      print("rx characteristic Subscribe");
      sleep(Duration(seconds:1));
      await onWritePressed(c);
      print("ble uart init process");
    });

    //if (mounted) {
    //  setState(() {});
    //}
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
  BluetoothCharacteristic get d => widget.transparentRx;
  BluetoothCharacteristic get e => widget.transparentTx;

  Future onSubscribePressed(BluetoothCharacteristic char) async {
    try {
      String op = char.isNotifying == false ? "Subscribe" : "Unubscribe";
      await char.setNotifyValue(char.isNotifying == false);
      //print("Subscribe.success");
      Snackbar.show(ABC.c, "$op : Success", success: true);
      if (char.properties.read) {
        await char.read();
      }
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Subscribe Error:", e), success: false);
      //print(e);
    }
  }

  Future<void> splitWrite(BluetoothCharacteristic char, List<int> value, {int timeout = 15}) async {
    int chunk = min(c.device.mtuNow - 3, 512);
    print("File length = " + growableList.length.toString());
    print("SplitWrite. credit = " + _credit.toString());

    //_txValue.clear();

    while (totalWrite < value.length) {
    //if(totalWrite < value.length) {
      if (_credit > 0) {
        List<int> subvalue = value.sublist(totalWrite, min(totalWrite + chunk, value.length));
        print("splitWrite len = " + subvalue.length.toString());
        await char.write(subvalue, withoutResponse: true, timeout: timeout);
        if (subvalue.length == chunk) {
          totalWrite += chunk;
        } else {
          totalWrite += subvalue.length;
        }
        _credit -= 1;
        print("totalWrite = " + totalWrite.toString());
        print(_credit);
      } else {
        print("Credit is zero!");
        //Future.delayed(const Duration(milliseconds: 500), (){
        //  print("delay 1 seconds");
        //});
        break;
      }
    }
    //print("splitWrite is completed.");
  }

  Future onWritePressed(BluetoothCharacteristic char) async {
    try {
      if (char.characteristicUuid == Guid.fromString("49535343-4C8A-39B3-2F49-511CFF073B7E")) {
        if (initialState == bleUARTState.FlowControl) {
          print("Enable ReliableBurstTransmit. command=0x14");
          await char.write([0x14], withoutResponse: char.properties.write);
          Snackbar.show(ABC.c, "Enable ReliableBurstTransmit", success: true);
        } else if (initialState == bleUARTState.UartEnable) {
          if(mode == bleUARTMode.UART){
            print("Send UART mode command");
            await char.write([0x80, 0x04, 0x01], withoutResponse: c.properties.write);
            Snackbar.show(ABC.c, "UART mode enable", success: true);
          }else{
            print("Send Loopback mode command");
            await char.write([0x80, 0x02, 0x01], withoutResponse: c.properties.write);
            Snackbar.show(ABC.c, "Loopback mode enable", success: true);
          }
        }
        else if (initialState == bleUARTState.TRP) {
          print("TRP mode");
          await char.write([0x80, 0x05, 0x04, 0x01], withoutResponse: c.properties.write);
          //Snackbar.show(ABC.c, "Send TRP command", success: true);
        } else if (initialState == bleUARTState.Complete) {
          print("Initial complete. credit = " + _credit.toString());
        } else if (initialState == bleUARTState.Start) {
          print("Data start");
          await char.write([0x80, 0x05, 0x01], withoutResponse: c.properties.write);
          //Snackbar.show(ABC.c, "Data start ", success: true);
        }
      } else {
        if (char.characteristicUuid == Guid.fromString("49535343-8841-43F4-A8D4-ECBE34729BB3")) {
          //print("Send test file");
          if(_credit == 0){
            print("Error. No credit.");
          }else{
            _value.clear;
            _value.add(_credit);
            CreateTestFile(lastNum: lastNumber);
            print("Send test file");
            totalWrite = 0;
            await splitWrite(char, growableList);
          }
        }

        //Snackbar.show(ABC.c, "Write: Success", success: true);
      }

      if (char.properties.read) {
        await char.read();
      }
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Write Error:", e), success: false);
      //print("Write error");
    }
  }

  void onClearBleData(){
    print("Clear ble data");
    totalWrite = 0;
    _rxValue.clear();
    _txValue.clear();

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    bool c_isNotifying = c.isNotifying;
    bool d_isNotifying = d.isNotifying;

    String config = "";
    String tmp = "BLE UART Setting: ";
    //if(lastNumber == 8334)
    config = (lastNumber == 8334 ? tmp += '100k,' : tmp += '500k,');
    config = (mode == bleUARTMode.LoopBack ? tmp += 'Loopback' : tmp += 'UART');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        /*ListTile(
        title: const Text('BLE UART Demo'),
        titleTextStyle: TextStyle(color: Colors.blue),
        trailing: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: onClearBleData,
        )),*/
        ExpansionTile(
            title: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(config, style: TextStyle(color: Colors.blue)),
              ],
            ),
            children: <Widget>[
              ElevatedButton(onPressed: onClearBleData, child: Text('Clear Data')),
              Row(children: <Widget>[
                ElevatedButton(
                  onPressed: () async {
                    /*mode = bleUARTMode.LoopBack;
                    if (mounted) {
                      setState(() {});
                    }*/
                    if(mode == bleUARTMode.UART){
                      print('Change to Loopback mode');
                      //mode = bleUARTMode.UART;
                      if(initialState == bleUARTState.Complete){
                        initialState = bleUARTState.UartEnable;
                        mode = bleUARTMode.LoopBack;
                        await onWritePressed(c);
                        //mode = bleUARTMode.LoopBack;
                      }else if(initialState == bleUARTState.FlowControl){
                        mode = bleUARTMode.LoopBack;
                      }
                      if (mounted) {
                        setState(() {});
                      }
                    }
                  }, 
                  child: Text('Loopback mode')),
                ElevatedButton(
                  onPressed: () async {
                    if(mode == bleUARTMode.LoopBack){
                      print('Change to UART mode');
                      if(initialState == bleUARTState.Complete){
                        initialState = bleUARTState.UartEnable;
                        mode = bleUARTMode.UART;
                        await onWritePressed(c);
                        //mode = bleUARTMode.UART;
                      }else if(initialState == bleUARTState.FlowControl){
                        mode = bleUARTMode.UART;
                      }
                      if (mounted) {
                        setState(() {});
                      }
                    }
                  }, 
                  child: Text('UART Mode')),
              ],),
              Row(children: <Widget>[
                ElevatedButton(
                  onPressed: (){
                    lastNumber = 8334;
                    if (mounted) {
                      setState(() {});
                    }
                  }, 
                  child: Text('100k.txt')),
                ElevatedButton(
                  onPressed: (){
                    lastNumber = 41667;
                    if (mounted) {
                      setState(() {});
                    }
                  }, 
                  child: Text('500k.txt')),
              ],),
              //ElevatedButton(onPressed: onClearBleData, child: Text('Set Loopbacl Mode')),
              /*
              ListTile(
                title: const Text('Clear Data'),
                titleTextStyle: TextStyle(color: Colors.blue),
                trailing: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: onClearBleData,
              )),*/
            ],
        ),
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
          subtitle: Row(mainAxisSize: MainAxisSize.min, children: [
            TextButton(
                onPressed: () async {
                  await onWritePressed(c);
                  if (mounted) {
                    setState(() {});
                  }
                },
                child: Text("Write")),
            TextButton(
                onPressed: () async {
                  await onSubscribePressed(c);
                  if (mounted) {
                    setState(() {});
                  }
                },
                child: Text(c_isNotifying ? "Unsubscribe" : "Subscribe")),
            TextButton(
                onPressed: () {
                  onClearBleData();
                },
                child: Text('Clear')),
            //autoControlButton
          ]),
          contentPadding: const EdgeInsets.all(0.0),
        ),
        ListTile(
          title: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text("MCHP_Transparent_Tx"),
              Text(widget.transparentTx.uuid.str, style: TextStyle(fontSize: 13)),
              //Text(_txValue.toString(), style: TextStyle(fontSize: 13, color: Colors.grey))
              Text(totalWrite.toString(), style: TextStyle(fontSize: 13, color: Colors.grey))
            ],
          ),
          subtitle: Row(mainAxisSize: MainAxisSize.min, children: [
            TextButton(
                onPressed: () async {
                  await onWritePressed(e);
                  if (mounted) {
                    setState(() {});
                  }
                },
                child: Text("WriteFile")),
          ]),
          contentPadding: const EdgeInsets.all(0.0),
        ),
        ListTile(
          title: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text("MCHP_Transparent_Rx"),
              Text(widget.transparentRx.uuid.str, style: TextStyle(fontSize: 13)),
              Text(_rxValue.length.toString(), style: TextStyle(fontSize: 13, color: Colors.grey))
            ],
          ),
          subtitle: Row(mainAxisSize: MainAxisSize.min, children: [
            TextButton(
                onPressed: () async {
                  await onSubscribePressed(d);
                  if (mounted) {
                    setState(() {});
                  }
                },
                child: Text(d_isNotifying ? "Unsubscribe" : "Subscribe"))
          ]),
          contentPadding: const EdgeInsets.all(0.0),
        )
      ],
    );
  }

  final growableList = <int>[];
  int totalWrite = 0;
  int totalRead = 0;
  int lastNumber = 8334;

  void CreateTestFile({int lastNum = 8334}) {
    //int k = 50;
    //k = 8334;
    //k = 41667;
    //50,1k.txt
    //834,10k.txt
    //8334,100k.txt
    //41667,500k.txt

    growableList.clear();

    //for (int i = 0; i < k; i++) {
    for (int i = 0; i < lastNum; i++) {
      for (int j = 0; j < (10 - (i + 1).toString().length); j++) {
        growableList.add(48);
      }
      growableList.addAll((i + 1).toString().codeUnits);
      growableList.addAll([0x0d, 0x0a]);
    }
  }
}
