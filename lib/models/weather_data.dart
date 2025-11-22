import 'package:flutter/material.dart';

class WeatherData {
  final String location;
  final int temperature;
  final int humidity;
  final String description;
  final String main;

  WeatherData({
    required this.location,
    required this.temperature,
    required this.humidity,
    required this.description,
    required this.main,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json, String location) {
    return WeatherData(
      location: location,
      temperature: (json['main']['temp'] as double).round(),
      humidity: json['main']['humidity'],
      description: json['weather'][0]['description'],
      main: json['weather'][0]['main'],
    );
  }

  IconData getWeatherIcon() {
    switch (main.toLowerCase()) {
      case 'clear':
        return Icons.wb_sunny;
      case 'clouds':
        return Icons.cloud;
      case 'rain':
        return Icons.grain;
      case 'thunderstorm':
        return Icons.flash_on;
      case 'snow':
        return Icons.ac_unit;
      case 'mist':
      case 'fog':
        return Icons.blur_on;
      default:
        return Icons.wb_cloudy;
    }
  }

  Color getConditionColor() {
    switch (main.toLowerCase()) {
      case 'clear':
        return Colors.orange;
      case 'clouds':
        return Colors.grey;
      case 'rain':
        return Colors.blue;
      case 'thunderstorm':
        return Colors.purple;
      case 'snow':
        return Colors.lightBlue;
      default:
        return Colors.grey;
    }
  }
}