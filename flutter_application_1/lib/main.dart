import 'package:flutter/material.dart';

void main() {
  runApp(const MyFirstApp());
}

class MyFirstApp extends StatelessWidget {
  const MyFirstApp({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('my first app bar'),
          backgroundColor: Colors.lightBlueAccent,
        ),
        body: Center(
          child: Text(
            'Hello World!'
          )
        )
      )
    );
  }
}