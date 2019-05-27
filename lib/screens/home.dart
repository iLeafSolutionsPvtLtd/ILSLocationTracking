import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:uber_clone/utils/geoLocation.dart';

import '../requests/google_maps_requests.dart';

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Mapv());
  }
}

class Mapv extends StatefulWidget {
  @override
  _MapState createState() => _MapState();
}

class _MapState extends State<Mapv> with SingleTickerProviderStateMixin {
  GoogleMapController mapController;
  GoogleMapsServices _googleMapsServices = GoogleMapsServices();
  TextEditingController locationController = TextEditingController();
  TextEditingController destinationController = TextEditingController();
  Map<MarkerId, Marker> _markers = <MarkerId, Marker>{};

  Location _locationService = new Location();
  bool _permission = false;

  static LatLng _initialPosition;
  LatLng _lastPosition = _initialPosition;
  final Set<Polyline> _polyLines = {};
  Animation<LatLng> animation;
  AnimationController controller;

  @override
  void initState() {
    initPlatformState();
    super.initState();
  }

  List<LatLng> pathList;

  LatLng _destination;
  int _markerIdCounter = 0;

  Timer _timer;
  int _start;

  void startTimer() {
    _start = 0;
    const oneSec = const Duration(seconds: 1);
    _timer = new Timer.periodic(
        oneSec,
        (Timer timer) => setState(() {
              if (_start == pathList.length) {
                timer.cancel();
              } else {
                _start = _start + 1;
                _destination = pathList[_start];
                LatLng nextPoint = pathList[_start + 1];
                ansCarMovement(
                    _markers.isNotEmpty ? _markers.values.first : null,
                    _lastPosition,
                    nextPoint);
              }
            }));
  }

  @override
  Widget build(BuildContext context) {
    return _initialPosition == null
        ? Container(
            alignment: Alignment.center,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          )
        : Stack(
            children: <Widget>[
              GoogleMap(
                initialCameraPosition:
                    CameraPosition(target: _initialPosition, zoom: 10.0),
                onMapCreated: onCreated,
                myLocationEnabled: true,
                mapType: MapType.normal,
                compassEnabled: true,
                markers: Set<Marker>.of(_markers.values),
                onCameraMove: _onCameraMove,
                polylines: _polyLines,
              ),
              Positioned(
                top: 50.0,
                right: 15.0,
                left: 15.0,
                child: Container(
                  height: 50.0,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3.0),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.grey,
                          offset: Offset(1.0, 5.0),
                          blurRadius: 10,
                          spreadRadius: 3)
                    ],
                  ),
                  child: TextField(
                    cursorColor: Colors.black,
                    controller: locationController,
                    decoration: InputDecoration(
                      icon: Container(
                        margin: EdgeInsets.only(left: 20, top: 5),
                        width: 10,
                        height: 10,
                        child: Icon(
                          Icons.location_on,
                          color: Colors.black,
                        ),
                      ),
                      hintText: "pick up",
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.only(left: 15.0, top: 16.0),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 105.0,
                right: 15.0,
                left: 15.0,
                child: Container(
                  height: 50.0,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3.0),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.grey,
                          offset: Offset(1.0, 5.0),
                          blurRadius: 10,
                          spreadRadius: 3)
                    ],
                  ),
                  child: TextField(
                    cursorColor: Colors.black,
                    controller: destinationController,
                    focusNode: FocusNode(),
                    textInputAction: TextInputAction.go,
                    onSubmitted: (value) async {
                      sendRequest(value);
                    },
                    decoration: InputDecoration(
                      icon: Container(
                        margin: EdgeInsets.only(left: 20, top: 5),
                        width: 10,
                        height: 10,
                        child: Icon(
                          Icons.local_taxi,
                          color: Colors.black,
                        ),
                      ),
                      hintText: "destination?",
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.only(left: 15.0, top: 16.0),
                    ),
                  ),
                ),
              ),
              _destination == null
                  ? Container()
                  : Positioned(
                      right: 101,
                      bottom: 10,
                      child: FloatingActionButton(
                        onPressed: () {
                          startTimer();
                        },
                        tooltip: "add marker",
                        backgroundColor: Colors.black26,
                        child: Text('GO'),
                      ),
                    )
            ],
          );
  }

  void onCreated(GoogleMapController controller) {
    setState(() {
      mapController = controller;
    });
  }

  void _addMarker(LatLng location, String address) {
    setState(() {
      MarkerId markerId = MarkerId(_markerIdVal());
      Marker marker = Marker(
          markerId: MarkerId(_lastPosition.toString()),
          position: location,
          infoWindow: InfoWindow(title: address, snippet: "go here"),
          icon: BitmapDescriptor.defaultMarker);
      setState(() {
        _markers[markerId] = marker;
      });
    });
  }

  String _markerIdVal({bool increment = false}) {
    String val = 'marker_id_$_markerIdCounter';
    if (increment) _markerIdCounter++;
    return val;
  }

  void createRoute(String encondedPoly) {
    setState(() {
      pathList = convertToLatLng(decodePoly(encondedPoly));
      _polyLines.add(Polyline(
          polylineId: PolylineId(_lastPosition.toString()),
          width: 5,
          points: pathList,
          color: Colors.black));
    });
  }

  initPlatformState() async {
    await _locationService.changeSettings(
        accuracy: LocationAccuracy.HIGH, interval: 1000);

    LocationData location;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      bool serviceStatus = await _locationService.serviceEnabled();
      print("Service status: $serviceStatus");
      if (serviceStatus) {
        _permission = await _locationService.requestPermission();
        print("Permission: $_permission");
        if (_permission) {
          location = await _locationService.getLocation();
          var locationName = await locationNameOfCoordinates(
              latitude: location.latitude, longitude: location.longitude);
          setState(() {
            _initialPosition = LatLng(location.latitude, location.longitude);
            locationController.text = locationName;
          });
//          _locationSubscription = _locationService.onLocationChanged().listen((LocationData result) async {
//            _currentCameraPosition = CameraPosition(
//                target: LatLng(result.latitude, result.longitude),
//                zoom: 16
//            );

//            final GoogleMapController controller = await _controller.future;
//            controller.animateCamera(CameraUpdate.newCameraPosition(_currentCameraPosition));

//            if(mounted){
//              setState(() {
////                _currentLocation = result;
//              });
//            }
//          });
        }
      } else {
        bool serviceStatusResult = await _locationService.requestService();
        print("Service status activated after request: $serviceStatusResult");
        if (serviceStatusResult) {
          initPlatformState();
        }
      }
    } on PlatformException catch (e) {
      print(e);
      if (e.code == 'PERMISSION_DENIED') {
        //error = e.message;
      } else if (e.code == 'SERVICE_STATUS_ERROR') {
        //error = e.message;
      }
      location = null;
    }
  }

  void sendRequest(String intendedLocation) async {
    LatLng destination = await getLatLong(intendedLocation);
    _destination = destination;
    _addMarker(destination, intendedLocation);
    String route = await _googleMapsServices.getRouteCoordinates(
        _initialPosition, destination);
    createRoute(route);
  }

  void _onCameraMove(CameraPosition position) async {
    setState(() {
      _lastPosition = position.target;
    });
  }

  void ansCarMovement(
      Marker marker, LatLng oldCordinate, LatLng newCordinate) async {
    double calBearing = getHeadingForDirection(oldCordinate, newCordinate);
    var config = createLocalImageConfiguration(context, size: Size(30, 30));
    animation = Tween<LatLng>(begin: oldCordinate, end: newCordinate)
        .animate(controller);
    BitmapDescriptor icon =
        await BitmapDescriptor.fromAssetImage(config, 'assets/car.png');
    MarkerId markerId = MarkerId(_markerIdVal());
    Marker marker = _markers[markerId];
    Marker updatedMarker = marker.copyWith(
        positionParam: newCordinate,
        rotationParam: calBearing,
        anchorParam: Offset(0.5, 0.5),
        iconParam: icon);
    setState(() {
      _markers[markerId] = updatedMarker;
      Future.delayed(Duration(seconds: 1), () async {
        mapController
            .animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
          target: _destination,
          zoom: 16.5,
        )));
      });
    });
  }
}
