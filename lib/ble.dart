import 'dart:async';
import 'dart:developer';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:hex/hex.dart';
import 'package:location/location.dart';
import "dart:typed_data";

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _foundDeviceWaitingToConnect = false;
  bool _scanStarted = false;
  bool _connected = false;

  late DiscoveredDevice bpDevice;
  final flutterReactiveBle = FlutterReactiveBle();
  late StreamSubscription<DiscoveredDevice> _scanStream;
  late QualifiedCharacteristic _rxCharacteristic;
// These are the UUIDs of your device
// 00001800-0000-1000-8000-00805f9b34fb
  final Uuid serviceUuid = Uuid.parse("00001800-0000-1000-8000-00805f9b34fb");
  final Uuid characteristicUuid = Uuid.parse("fff1");
  final Uuid characteristicUuid2 = Uuid.parse("fff2");
  List allList = [];
  var newList = [];
  void _startScan() async {
    bool permGranted = false;
    setState(() {
      _scanStarted = true;
    });
    PermissionStatus permission;
    if (Platform.isAndroid) {
      permission = await Location().requestPermission();
      if (permission == PermissionStatus.granted) permGranted = true;
    }

    if (permGranted) {
      _scanStream =
          flutterReactiveBle.scanForDevices(withServices: []).listen((device) {
        log(device.name);
        // Change this string to what you defined in Zephyr
        if (device.name == 'Smart Blood Pressure Monitor') {
          log(device.toString());
          setState(() {
            bpDevice = device;
            _foundDeviceWaitingToConnect = true;
          });
        }
      });
    }
  }

  void _connectToDevice() {
    _scanStream.cancel();

    Stream<ConnectionStateUpdate> _currentConnectionStream = flutterReactiveBle
        .connectToAdvertisingDevice(
            id: bpDevice.id,
            prescanDuration: const Duration(seconds: 1),
            withServices: []);
    _currentConnectionStream.listen((event) {
      switch (event.connectionState) {
        case DeviceConnectionState.connected:
          {
            log('connected');
            _rxCharacteristic = QualifiedCharacteristic(
                serviceId: serviceUuid,
                characteristicId: characteristicUuid,
                deviceId: event.deviceId);

            setState(() {
              _foundDeviceWaitingToConnect = false;
              _connected = true;
            });
            break;
          }
        // Can add various state state updates on disconnect
        case DeviceConnectionState.disconnected:
          {
            break;
          }
        default:
      }
    });
  }

  void subscribe() async {
    allList = [];
    if (_connected) {
      final characteristic = QualifiedCharacteristic(
          serviceId: serviceUuid,
          characteristicId: characteristicUuid,
          deviceId: bpDevice.id);

      if (_connected) {
        flutterReactiveBle.subscribeToCharacteristic(characteristic).listen(
            (data) {
          print("SUB LISTEN");
          log(data.toString());
          if (data.length == 20 ||
              data.length == 7 && !data.contains(allList)) {
            allList.addAll(data);
            var newList = List.from(allList);
            print(newList);
            listSeting(allList);
          }
        }, onError: (dynamic error) {
          print("SUB ERROR");

          print(error);
        });
      }
    }
  }

  Uint8List int32bytes(int value) =>
      Uint8List(4)..buffer.asInt32List()[0] = value;

  date() async {
    var utc = DateTime.now();
    var epoc = utc.millisecondsSinceEpoch;
    var str = epoc.toString();
    str = str.substring(0, str.length - 3);
    var intEpoc = int.parse(str);
    var utcByteArr = int32bytes(intEpoc);

    var configData2 = [
      -91,
      34,
      1,
      9,
      0,
      106,
      1,
      -127,
      -96,
      0,
      utcByteArr[0],
      utcByteArr[1],
      utcByteArr[2],
      utcByteArr[3],
      0,
    ];

    // var s = Uint8List.fromList(configData2);

    final characteristic = QualifiedCharacteristic(
        serviceId: serviceUuid,
        characteristicId: characteristicUuid2,
        deviceId: bpDevice.id);
    await flutterReactiveBle.writeCharacteristicWithResponse(characteristic,
        value: configData2);
  }

  clearrecords() async {
    final characteristic = QualifiedCharacteristic(
        serviceId: serviceUuid,
        characteristicId: characteristicUuid2,
        deviceId: bpDevice.id);
    await flutterReactiveBle
        .writeCharacteristicWithResponse(characteristic, value: [
      -91,
      34,
      5,
      4,
      0,
      -104,
      1,
      -14,
      -92,
      0,
    ]);
  }

  write() async {
    final characteristic = QualifiedCharacteristic(
        serviceId: serviceUuid,
        characteristicId: characteristicUuid2,
        deviceId: bpDevice.id);
    await flutterReactiveBle.writeCharacteristicWithResponse(characteristic,
        value: [-91, 34, 3, 5, 0, -103, 1, -15, -92, 0, 1]);
  }

  listSeting(allList) {
    newList = [];
    var cutList = List.from(allList);

    log(cutList.toString());
    cutList.removeRange(0, 12);
    log(cutList.toString());

    int listSize = 15;
    for (var i = 0; i < cutList.length; i += listSize) {
      newList.add(cutList.sublist(
          i, i + listSize > cutList.length ? cutList.length : i + listSize));
    }
    timeGet(newList);
    log(newList.toString());
  }

  timeGet(newList) {
    print(newList);
    List<int> readTime = [];
    List<int> readSystolic = [];
    List<int> readDiastolic = [];
    List<int> readPulse = [];
    for (var elem in newList) {
      readTime = [];
      readSystolic = [];
      readDiastolic = [];
      readPulse = [];
      var dateTime = elem.sublist(0, 4);
      var sys = elem.sublist(5, 6);
      var dia = elem.sublist(7, 8);
      var pul = elem.sublist(11, 12);

      readTime = List.from(dateTime.reversed.toList());
      var hexint = hex(readTime);
      DateTime date1 =
          DateTime.fromMillisecondsSinceEpoch(hexint * 1000, isUtc: true);
      print(date1);

      readSystolic = List.from(sys.reversed.toList());
      print(hex(readSystolic));

      readDiastolic = List.from(dia.reversed.toList());
      print(hex(readDiastolic));

      readPulse = List.from(pul.reversed.toList());
      print(hex(readPulse));
    }
  }

  hex(List<int> list) {
    String hexVal = HEX.encode(list);
    final number = int.parse(hexVal, radix: 16);
    print(number);
    return number;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(255, 255, 255, 1),
      persistentFooterButtons: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            primary: Colors.blue, // background
            onPrimary: Colors.white, // foreground
          ),
          onPressed: () {
            _startScan();
          },
          child: const Icon(Icons.search),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            primary: Colors.blue, // background
            onPrimary: Colors.white, // foreground
          ),
          onPressed: () {
            _connectToDevice();
          },
          child: const Icon(Icons.bluetooth),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            primary: Colors.blue, // background
            onPrimary: Colors.white, // foreground
          ),
          onPressed: () {
            subscribe();
          },
          child: const Icon(Icons.notification_add),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            primary: Colors.blue, // background
            onPrimary: Colors.white, // foreground
          ),
          onPressed: () {
            date();
          },
          child: const Icon(Icons.date_range),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            primary: Colors.blue, // background
            onPrimary: Colors.white, // foreground
          ),
          onPressed: () {
            write();
          },
          child: const Icon(Icons.book),
        ),
        // ElevatedButton(
        //   style: ElevatedButton.styleFrom(
        //     primary: Colors.blue, // background
        //     onPrimary: Colors.white, // foreground
        //   ),
        //   onPressed: () {
        //     // listSeting();
        //   },
        //   child: const Icon(Icons.settings),
        // ),
        // ElevatedButton(
        //   style: ElevatedButton.styleFrom(
        //     primary: Colors.blue, // background
        //     onPrimary: Colors.white, // foreground
        //   ),
        //   onPressed: () {
        //     // timeGet();
        //   },
        //   child: const Icon(Icons.timelapse),
        // ),
      ],
    );
  }
}
