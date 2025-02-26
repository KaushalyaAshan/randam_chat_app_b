/*import 'package:flutter/material.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'no_internet_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late InternetConnectionChecker _connectionChecker;

  @override
  void initState() {
    super.initState();
    _connectionChecker = InternetConnectionChecker();
    _monitorInternetConnection();
  }

  void _monitorInternetConnection() {
    _connectionChecker.onStatusChange.listen((status) {
      if (status == InternetConnectionStatus.disconnected) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => NoInternetScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home Screen'),
      ),
      body: Center(
        child: Text('You are online!'),
      ),
    );
  }

  @override
  void dispose() {
    _connectionChecker.dispose();
    super.dispose();
  }
}
*/