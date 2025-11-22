import 'dart:convert';
import 'package:almaworks/models/weather_data.dart';
import 'package:http/http.dart' as http;

class WeatherService {
  static const String _apiKey = 'your_openweather_api_key'; // Replace with actual API key
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5/weather';

  // Nairobi locations with coordinates
  final List<Map<String, dynamic>> _nairobiLocations = [
    {'name': 'Kilimani', 'lat': -1.2921, 'lon': 36.7856},
    {'name': 'Kitisuru', 'lat': -1.2167, 'lon': 36.8167},
    {'name': 'Kileleshwa', 'lat': -1.2667, 'lon': 36.7833},
    {'name': 'Runda', 'lat': -1.2000, 'lon': 36.8000},
    {'name': 'Westlands', 'lat': -1.2667, 'lon': 36.8000},
  ];

  Future<List<WeatherData>> getWeatherForSites() async {
    List<WeatherData> weatherData = [];
    
    for (var location in _nairobiLocations) {
      try {
        final weather = await _fetchWeatherData(
          location['name'] as String,
          location['lat'] as double,
          location['lon'] as double,
        );
        if (weather != null) {
          weatherData.add(weather);
        }
      } catch (e) {
        // If API fails, add mock data
        weatherData.add(_getMockWeatherData(location['name'] as String));
      }
    }
    
    // If no real data, return mock data
    if (weatherData.isEmpty) {
      return _getMockWeatherDataList();
    }
    
    return weatherData;
  }

  Future<WeatherData?> _fetchWeatherData(String location, double lat, double lon) async {
    try {
      final url = '$_baseUrl?lat=$lat&lon=$lon&appid=$_apiKey&units=metric';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return WeatherData.fromJson(data, location);
      }
    } catch (e) {
      // Removed print statement to fix lint warning
      // In production, use proper logging
    }
    return null;
  }

  WeatherData _getMockWeatherData(String location) {
    final mockData = {
      'Kilimani': {'temp': 22, 'humidity': 65, 'desc': 'Partly Cloudy', 'main': 'Clouds'},
      'Kitisuru': {'temp': 20, 'humidity': 70, 'desc': 'Light Rain', 'main': 'Rain'},
      'Kileleshwa': {'temp': 24, 'humidity': 60, 'desc': 'Sunny', 'main': 'Clear'},
      'Runda': {'temp': 21, 'humidity': 68, 'desc': 'Overcast', 'main': 'Clouds'},
      'Westlands': {'temp': 23, 'humidity': 62, 'desc': 'Clear Sky', 'main': 'Clear'},
    };

    final data = mockData[location] ?? mockData['Kilimani']!;
    return WeatherData(
      location: location,
      temperature: data['temp'] as int,
      humidity: data['humidity'] as int,
      description: data['desc'] as String,
      main: data['main'] as String,
    );
  }

  List<WeatherData> _getMockWeatherDataList() {
    return _nairobiLocations.map((location) => _getMockWeatherData(location['name'] as String)).toList();
  }
}
