import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
// Calls the package we made
import 'package:usbserial/usbSerial.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Size size = const Size(0,0);

  // Class from usbserial.dart package
  USBSerialMacOS usbserial = USBSerialMacOS();
  late StreamSubscription usbSubscription;
  List<USBDevice> usbDevices = [];
  String received = '';
  List<DropdownMenuItem> menue = [];
  USBDevice? connectedDevice;
  TextEditingController toSend = TextEditingController();
  ScrollController scrollController = ScrollController();

  @override
  void initState(){
    usbserial.transmission.listen((event) { 
      setState(() {
        received += '$event\n';
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), 
            curve: Curves.ease
          );
      });
    });
    usbserial.devices.listen((event) {
      print(event);
      if(event.added){
        usbDevices.add(event);
      }
      else{
        event.added = true;
        usbDevices.remove(event);
      }
      setMenueItems();
    });
    usbserial.findDevices().then((value){
      usbDevices = value;
      setMenueItems();
      print(usbDevices);
    });
    
    super.initState();
  }

  @override
  void dispose(){
    usbserial.dispose();
    super.dispose();
  }
  void sendString(){
    if(toSend.text != ''){
      if(usbserial.isPortOpened){
        usbserial.writeString('${toSend.text}\n').then((written){
          print(written);
        });
      }
      toSend.clear();
    }
  }
  void setMenueItems(){
    menue = [];
      menue.add(
        const DropdownMenuItem(
          value: null,
          child: Text(
            'Pick a Device.', 
            overflow: TextOverflow.ellipsis,
          )
        )
      );
    for(int i = 0; i < usbDevices.length;i++){
      menue.add(
        DropdownMenuItem(
          value: usbDevices[i],
          child: Text(
            '${usbDevices[i].path}/${usbDevices[i].name}', 
            overflow: TextOverflow.ellipsis,
          )
        )
      );
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    size = MediaQuery.of(context).size;
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          Row(
            children: [
              Container(
                margin: const EdgeInsets.all(10),
                width: size.width-65,
                height:45,
                padding: const EdgeInsets.only(left:5, right:5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.all(Radius.circular(5)),
                  border: Border.all(
                    color: Colors.black,
                    width: 1
                  )
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton <dynamic>(
                    dropdownColor: Colors.white,
                    isExpanded: true,
                    items: menue,
                    value: connectedDevice,
                    isDense: true,
                    focusColor: Colors.grey[350],
                    //style: style,
                    onChanged: (val){
                      setState(() {
                        connectedDevice = val;
                      });
                    },
                  ),
                ),
              ),
              if(connectedDevice != null)InkWell(
                onTap: ()async{
                  if(connectedDevice != null){
                    if(!usbserial.isPortOpened){
                      String port = connectedDevice!.path;
                      bool? setS = await usbserial.setSettings(PortSettings(
                        receiveRate: BaudRate.baud115200,
                        transmitRate: BaudRate.baud115200,
                      ));
                      await usbserial.openPort(port) ?? false;
                    }
                    else{
                      usbserial.closePort();
                      received = '';
                    }
                    setState(() {
                      
                    });
                  }
                },
                child: Icon(
                  usbserial.isPortOpened?Icons.search_off:Icons.search,
                  size: 35,
                ),
              )
            ]
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(10,0,10,10),
            width: size.width-20,
            height: 45,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.all(Radius.circular(5)),
              border: Border.all(
                color: Colors.black,
                width: 1
              )
            ),
            child:Row(
              children: [
                SizedBox(
                  width: size.width-65,
                  child:TextField(
                    controller: toSend,
                      onSubmitted: (val){
                        sendString();
                      },
                      //onEditingComplete:onEditingComplete,
                      //style: (textStyle == null)?Theme.of(context).primaryTextTheme.bodyText2:textStyle,
                      decoration: const InputDecoration(
                        isDense: true,
                        //labelText: label,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(
                            Radius.circular(5),
                          ),
                          borderSide:  BorderSide(
                              width: 0, 
                              style: BorderStyle.none,
                          ),
                        ),
                        hintText: 'Text to write to the usb.'
                      ),
                    ),
                ),
                if(usbserial.isPortOpened)InkWell(
                  onTap: (){
                    sendString();
                  },
                  child: const Icon(
                    Icons.send,
                    size: 35,
                  ),
                )
              ]
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(10,0,10,10),
            padding: const EdgeInsets.all(5),
            width: size.width-20,
            height: size.height-130,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.all(Radius.circular(5)),
              border: Border.all(
                color: Colors.black,
                width: 1
              )
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              child: Text(
                received,
              ),
            )
          ),
        ],
      ),
    );
  }
}
