import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import "characteristic_tile.dart";

class ServiceTile extends StatelessWidget {
  final BluetoothService service;
  final List<CharacteristicTile> characteristicTiles;

  //final BluetoothCharacteristic transparentCtrl;
  //final BluetoothCharacteristic transparentTx;
  //final BluetoothCharacteristic transparentRx;

  const ServiceTile({Key? key, required this.service, required this.characteristicTiles}) : super(key: key);
  //const ServiceTile({Key? key, required this.service, required this.transparentCtrl, required this.transparentTx, required this.transparentRx}) : super(key: key);

  Widget buildUuid(BuildContext context) {
    String uuid = '0x${service.uuid.str.toUpperCase()}';
    return Text(uuid, style: TextStyle(fontSize: 13));
  }

  @override
  Widget build(BuildContext context) {
    
    return characteristicTiles.isNotEmpty
        ? ExpansionTile(
            title: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                //const Text('Service', style: TextStyle(color: Colors.blue)),
                const Text('MCHP Transparent Service', style: TextStyle(color: Colors.blue)),
                buildUuid(context),
              ],
            ),
            children: characteristicTiles,
          )
        : ListTile(
            title: const Text('Service'),
            subtitle: buildUuid(context),
          );
          
  }
}
