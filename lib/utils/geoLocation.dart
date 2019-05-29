import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_google_places_autocomplete/flutter_google_places_autocomplete.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_webservice/places.dart';

Future<String> locationNameOfCoordinates(
    {double latitude, double longitude}) async {
  List<Placemark> placemark =
      await Geolocator().placemarkFromCoordinates(latitude, longitude);
  return placemark.first.name;
}

Future<LatLng> getLatLong(String intendedLocation) async {
  List<Placemark> placemark =
      await Geolocator().placemarkFromAddress(intendedLocation);
  double latitude = placemark[0].position.latitude;
  double longitude = placemark[0].position.longitude;
  LatLng destination = LatLng(latitude, longitude);
  return destination;
}

double degreesToRadians(double value) {
  return value * pi / 180.0;
}

double radianToDegrees(double value) {
  return value * 180.0 / pi;
}

double getHeadingForDirection(LatLng fromCordinate, LatLng toCordinate) {
  double fLat = degreesToRadians(fromCordinate.latitude);
  double fLon = degreesToRadians(fromCordinate.longitude);
  double tLat = degreesToRadians(toCordinate.latitude);
  double tLon = degreesToRadians(toCordinate.longitude);
  double degree = atan2(sin(tLon - fLon) * cos(tLat),
      cos(fLat) * sin(tLat) - sin(fLat) * cos(tLat) * cos(tLon - fLon));
  degree = radianToDegrees(degree);
  return (degree >= 0) ? degree : (360 + degree);
}

/*
* [12.12, 312.2, 321.3, 231.4, 234.5, 2342.6, 2341.7, 1321.4]
* (0-------1-------2------3------4------5-------6-------7)
* */

//  this method will convert list of doubles into latlng
List<LatLng> convertToLatLng(List points) {
  List<LatLng> result = <LatLng>[];
  for (int i = 0; i < points.length; i++) {
    if (i % 2 != 0) {
      result.add(LatLng(points[i - 1], points[i]));
    }
  }
  return result;
}

List decodePoly(String poly) {
  var list = poly.codeUnits;
  var lList = new List();
  int index = 0;
  int len = poly.length;
  int c = 0;
// repeating until all attributes are decoded
  do {
    var shift = 0;
    int result = 0;

    // for decoding value of one attribute
    do {
      c = list[index] - 63;
      result |= (c & 0x1F) << (shift * 5);
      index++;
      shift++;
    } while (c >= 32);
    /* if value is negetive then bitwise not the value */
    if (result & 1 == 1) {
      result = ~result;
    }
    var result1 = (result >> 1) * 0.00001;
    lList.add(result1);
  } while (index < len);

/*adding to previous value as done in encoding */
  for (var i = 2; i < lList.length; i++) lList[i] += lList[i - 2];

  print(lList.toString());

  return lList;
}

Future<LatLng> getLocationFromPlaces(String query, BuildContext context) async {
  String gMapAPI = "";
  Prediction p = await showGooglePlacesAutocomplete(
      context: context,
      apiKey: gMapAPI,
      mode: Mode.overlay, // Mode.fullscreen
      language: "fr",
      components: [new Component(Component.country, "fr")]);
  GoogleMapsPlaces _places = new GoogleMapsPlaces(apiKey: gMapAPI);
  var details = await _places.getDetailsByPlaceId(p.placeId);
  var lat = details.result.geometry.location.lat;
  var lon = details.result.geometry.location.lng;

  return LatLng(lat, lon);
}
