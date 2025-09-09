import 'package:almaworks/models/weather_data.dart';
import 'package:almaworks/services/weather_service.dart';
import 'package:flutter/material.dart';

class WeatherWidget extends StatefulWidget {
  const WeatherWidget({super.key});

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> {
  final WeatherService _weatherService = WeatherService();
  List<WeatherData> _weatherData = [];
  bool _isLoading = true;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadWeatherData();
  }

  Future<void> _loadWeatherData() async {
    try {
      final data = await _weatherService.getWeatherForSites();
      if (mounted) {
        setState(() {
          _weatherData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    
    return Card(
      elevation: 2,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.wb_sunny,
                  color: Colors.orange,
                  size: isMobile ? 20 : 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Weather Report',
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.refresh,
                    size: isMobile ? 18 : 20,
                  ),
                  onPressed: _loadWeatherData,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _buildWeatherContent(isMobile, isTablet),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isMobile ? 8 : 12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue,
                    size: isMobile ? 14 : 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Weather updates every 30 minutes',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: isMobile ? 10 : 12,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherContent(bool isMobile, bool isTablet) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (_weatherData.isEmpty) {
      return Center(
        child: Text(
          'No weather data available',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: isMobile ? 12 : 14,
          ),
        ),
      );
    }
    
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: _isExpanded ? _weatherData.length : (_weatherData.length > 4 ? 4 : _weatherData.length),
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(bottom: isMobile ? 8 : 12),
                child: _buildWeatherItem(_weatherData[index], isMobile, isTablet),
              );
            },
          ),
        ),
        if (_weatherData.length > 4)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Text(_isExpanded ? 'Show Less' : 'View All Weather Data (${_weatherData.length})'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWeatherItem(WeatherData weather, bool isMobile, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 8 : 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: isMobile ? 28 : 32,
            height: isMobile ? 28 : 32,
            decoration: BoxDecoration(
              color: weather.getConditionColor().withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(isMobile ? 14 : 16),
            ),
            child: Icon(
              weather.getWeatherIcon(),
              color: weather.getConditionColor(),
              size: isMobile ? 14 : 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  weather.location,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 12 : 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  weather.description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: isMobile ? 10 : 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${weather.temperature}°C',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 14 : 16,
                ),
              ),
              Text(
                '${weather.humidity}%',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: isMobile ? 10 : 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
