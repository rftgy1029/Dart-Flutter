import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

import '../models/weather_models.dart';

class GridCoordinate {
  final int nx;
  final int ny;
  GridCoordinate(this.nx, this.ny);
}

GridCoordinate latLngToGrid(double lat, double lng) {
  const double reRadius = 6371.00877; // 지구 반경(km)
  const double gridSpacing = 5.0; // 격자 간격(km)
  const double slat1 = 30.0; // 투영 위도1(degree)
  const double slat2 = 60.0; // 투영 위도2(degree)
  const double olon = 126.0; // 기준점 경도(degree)
  const double olat = 38.0; // 기준점 위도(degree)
  const double xo = 43; // 기준점 X좌표(GRID)
  const double yo = 136; // 기준점 Y좌표(GRID)

  final double degRad = math.pi / 180.0;

  final double re = reRadius / gridSpacing;
  final double slat1Rad = slat1 * degRad;
  final double slat2Rad = slat2 * degRad;
  final double olonRad = olon * degRad;
  final double olatRad = olat * degRad;

  double sn = math.tan(math.pi * 0.25 + slat2Rad * 0.5) / math.tan(math.pi * 0.25 + slat1Rad * 0.5);
  sn = math.log(math.cos(slat1Rad) / math.cos(slat2Rad)) / math.log(sn);
  double sf = math.tan(math.pi * 0.25 + slat1Rad * 0.5);
  sf = math.pow(sf, sn) * math.cos(slat1Rad) / sn;
  double ro = math.tan(math.pi * 0.25 + olatRad * 0.5);
  ro = re * sf / math.pow(ro, sn);

  double ra = math.tan(math.pi * 0.25 + lat * degRad * 0.5);
  ra = re * sf / math.pow(ra, sn);
  double theta = lng * degRad - olonRad;
  if (theta > math.pi) theta -= 2.0 * math.pi;
  if (theta < -math.pi) theta += 2.0 * math.pi;
  theta *= sn;

  final int nxVal = (ra * math.sin(theta) + xo + 0.5).floor();
  final int nyVal = (ro - ra * math.cos(theta) + yo + 0.5).floor();

  return GridCoordinate(nxVal, nyVal);
}

class KmaData {
  final CurrentWeather current;
  final List<HourlyWeather> hourly;
  final List<DailyWeather> daily;

  KmaData({
    required this.current,
    required this.hourly,
    required this.daily,
  });
}

class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _apiKeyPrefsKey = 'kma_api_service_key';
  
  //기에 공공데이터포털(data.go.kr)에서 발급받은 기상청 API 서비스키를 입력할 수 있습니다.
  //인코딩되지 않은 Decoding 키 입력을 권장합니다.
  static String serviceKey = '042d21234294c93136fb3ea51c0ff3f89c78e525fc4486f991a8e533381a1bc4';

  static const City seoul = City(
    name: 'Seoul',
    country: 'South Korea',
    admin1: 'Seoul',
    latitude: 37.566,
    longitude: 126.9784,
  );

  static Future<void> loadSavedServiceKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = prefs.getString(_apiKeyPrefsKey);
      if (key != null && key.isNotEmpty) {
        serviceKey = key;
      }
    } catch (_) {}
  }

  static Future<void> saveServiceKey(String key) async {
    serviceKey = key;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_apiKeyPrefsKey, key);
    } catch (_) {}
  }

  Future<List<City>> searchCities(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return const [];
    }

    final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': trimmedQuery,
      'count': '8',
      'language': 'ko',
      'format': 'json',
    });

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw WeatherException('도시 검색에 실패했어요. 잠시 후 다시 시도해 주세요.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final results = json['results'] as List<dynamic>? ?? const [];
    return results
        .map((item) => City.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<WeatherForecast> fetchForecast(City city) async {
    final isInKorea = city.latitude >= 32.0 &&
        city.latitude <= 39.0 &&
        city.longitude >= 123.0 &&
        city.longitude <= 133.0;

    // 1. Open-Meteo 예보를 기본 베이스로 가져옴 (7일치 일기예보 및 타임존 확보용)
    WeatherForecast baseForecast;
    try {
      baseForecast = await _fetchOpenMeteoForecast(city);
    } catch (e) {
      if (!isInKorea || serviceKey.isEmpty || serviceKey == 'YOUR_API_KEY_HERE') {
        rethrow;
      }
      baseForecast = _createDummyForecast(city);
    }

    // 2. 대한민국 지역이 아니거나 기상청 API 키가 입력되지 않은 경우 Open-Meteo 데이터를 그대로 노출
    if (!isInKorea || serviceKey.isEmpty || serviceKey == 'YOUR_API_KEY_HERE') {
      return baseForecast;
    }

    // 3. 기상청 API 호출 및 데이터 병합
    try {
      final grid = latLngToGrid(city.latitude, city.longitude);
      final kmaData = await _fetchKmaForecast(grid.nx, grid.ny);
      return _mergeKmaForecast(baseForecast, kmaData);
    } catch (e) {
      // 웹 환경에서의 CORS 또는 Mixed Content 오류 등으로 기상청 API 호출이 실패할 경우,
      // 앱이 완전히 멈추지 않도록 Open-Meteo 예보(baseForecast)를 반환하는 폴백(Fallback)을 적용합니다.
      print('기상청 API 호출 실패 (Open-Meteo 데이터로 대체): $e');
      return baseForecast;
    }
  }

  Future<WeatherForecast> _fetchOpenMeteoForecast(City city) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': city.latitude.toString(),
      'longitude': city.longitude.toString(),
      'current':
          'temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m',
      'hourly': 'temperature_2m,precipitation_probability,weather_code',
      'daily':
          'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max',
      'timezone': 'auto',
      'forecast_days': '7',
    });

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw WeatherException('날씨 정보를 불러오지 못했어요. 네트워크를 확인해 주세요.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return _parseForecast(city, json);
  }

  WeatherForecast _parseForecast(City city, Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>;
    final hourly = json['hourly'] as Map<String, dynamic>;
    final daily = json['daily'] as Map<String, dynamic>;

    return WeatherForecast(
      city: city,
      timezone: json['timezone'] as String? ?? 'Local',
      current: CurrentWeather(
        time: DateTime.parse(current['time'] as String),
        temperature: _doubleAt(current, 'temperature_2m'),
        apparentTemperature: _doubleAt(current, 'apparent_temperature'),
        humidity: _intAt(current, 'relative_humidity_2m'),
        precipitation: _doubleAt(current, 'precipitation'),
        weatherCode: _intAt(current, 'weather_code'),
        windSpeed: _doubleAt(current, 'wind_speed_10m'),
        isDay: _intAt(current, 'is_day') == 1,
      ),
      hourly: _parseHourly(hourly),
      daily: _parseDaily(daily),
    );
  }

  List<HourlyWeather> _parseHourly(Map<String, dynamic> hourly) {
    final times = hourly['time'] as List<dynamic>;
    final temperatures = hourly['temperature_2m'] as List<dynamic>;
    final probabilities = hourly['precipitation_probability'] as List<dynamic>;
    final codes = hourly['weather_code'] as List<dynamic>;

    final now = DateTime.now();
    final items = <HourlyWeather>[];

    for (var index = 0; index < times.length; index++) {
      final time = DateTime.parse(times[index] as String);
      if (time.isBefore(now.subtract(const Duration(hours: 1)))) {
        continue;
      }

      items.add(
        HourlyWeather(
          time: time,
          temperature: (temperatures[index] as num).toDouble(),
          precipitationProbability:
              (probabilities[index] as num?)?.toInt() ?? 0,
          weatherCode: (codes[index] as num).toInt(),
        ),
      );

      if (items.length == 12) {
        break;
      }
    }

    return items;
  }

  List<DailyWeather> _parseDaily(Map<String, dynamic> daily) {
    final dates = daily['time'] as List<dynamic>;
    final maxTemps = daily['temperature_2m_max'] as List<dynamic>;
    final minTemps = daily['temperature_2m_min'] as List<dynamic>;
    final probabilities =
        daily['precipitation_probability_max'] as List<dynamic>;
    final codes = daily['weather_code'] as List<dynamic>;

    return List.generate(dates.length, (index) {
      return DailyWeather(
        date: DateTime.parse(dates[index] as String),
        maxTemperature: (maxTemps[index] as num).toDouble(),
        minTemperature: (minTemps[index] as num).toDouble(),
        precipitationProbability: (probabilities[index] as num?)?.toInt() ?? 0,
        weatherCode: (codes[index] as num).toInt(),
      );
    });
  }

  WeatherForecast _createDummyForecast(City city) {
    final now = DateTime.now();
    return WeatherForecast(
      city: city,
      current: CurrentWeather(
        time: now,
        temperature: 0.0,
        apparentTemperature: 0.0,
        humidity: 0,
        precipitation: 0.0,
        weatherCode: 0,
        windSpeed: 0.0,
        isDay: true,
      ),
      hourly: const [],
      daily: List.generate(7, (index) {
        return DailyWeather(
          date: now.add(Duration(days: index)),
          maxTemperature: 0.0,
          minTemperature: 0.0,
          precipitationProbability: 0,
          weatherCode: 0,
        );
      }),
      timezone: 'Asia/Seoul',
    );
  }

  // 기상청 API 호출
  Future<KmaData> _fetchKmaForecast(int nx, int ny) async {
    final kst = DateTime.now().toUtc().add(const Duration(hours: 9));

    final ncstParams = _getUltraSrtNcstDateTime(kst);
    final vilageParams = _getVilageFcstDateTime(kst);

    final ncstUri = Uri.https('apis.data.go.kr', '/1360000/VilageFcstInfoService_2.0/getUltraSrtNcst', {
      'serviceKey': serviceKey,
      'pageNo': '1',
      'numOfRows': '10',
      'dataType': 'JSON',
      'base_date': ncstParams['base_date']!,
      'base_time': ncstParams['base_time']!,
      'nx': nx.toString(),
      'ny': ny.toString(),
    });

    final vilageUri = Uri.https('apis.data.go.kr', '/1360000/VilageFcstInfoService_2.0/getVilageFcst', {
      'serviceKey': serviceKey,
      'pageNo': '1',
      'numOfRows': '1000', // 충분한 범위 확보
      'dataType': 'JSON',
      'base_date': vilageParams['base_date']!,
      'base_time': vilageParams['base_time']!,
      'nx': nx.toString(),
      'ny': ny.toString(),
    });

    var ncstUriToSend = ncstUri;
    var vilageUriToSend = vilageUri;

    if (kIsWeb) {
      ncstUriToSend = Uri.parse('https://api.allorigins.win/raw?url=${Uri.encodeComponent(ncstUri.toString())}');
      vilageUriToSend = Uri.parse('https://api.allorigins.win/raw?url=${Uri.encodeComponent(vilageUri.toString())}');
    }

    final ncstResponse = await _client.get(ncstUriToSend);
    _validateKmaResponse(ncstResponse);

    final vilageResponse = await _client.get(vilageUriToSend);
    _validateKmaResponse(vilageResponse);

    final ncstJson = jsonDecode(ncstResponse.body) as Map<String, dynamic>;
    final vilageJson = jsonDecode(vilageResponse.body) as Map<String, dynamic>;

    return _parseKmaData(kst, ncstJson, vilageJson);
  }

  void _validateKmaResponse(http.Response response) {
    if (response.statusCode != 200) {
      throw WeatherException('기상청 서버 응답 실패 (코드: ${response.statusCode})');
    }

    final body = response.body.trim();
    if (!body.startsWith('{')) {
      if (body.contains('SERVICE_KEY_IS_NOT_REGISTERED_ERROR')) {
        throw WeatherException('기상청 API 서비스키가 올바르지 않거나 등록되지 않았습니다. [인증키 설정]에서 Decoding 키가 맞는지 확인해 주세요.');
      }
      if (body.contains('LIMITED_NUMBER_OF_SERVICE_REQUEST_EXCEEDS_ERROR')) {
        throw WeatherException('기상청 API 호출 허용 트래픽을 초과했습니다.');
      }
      if (body.contains('errMsg') || body.contains('returnAuthMsg') || body.contains('OpenAPI_ServiceResponse')) {
        throw WeatherException('기상청 API 인증 오류가 발생했습니다. 서비스키를 확인해 주세요.');
      }
      throw WeatherException('기상청 API 응답을 분석할 수 없습니다. (JSON 포맷이 아님)');
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    final header = json['response']?['header'] as Map<String, dynamic>?;
    if (header == null) {
      throw WeatherException('기상청 API 응답 양식이 올바르지 않습니다.');
    }

    final resultCode = header['resultCode']?.toString() ?? '';
    final resultMsg = header['resultMsg']?.toString() ?? '';

    if (resultCode != '00' && resultCode != '0') {
      if (resultCode == '03') {
        throw WeatherException('기상청 API 오류: 해당하는 시간의 데이터가 아직 갱신되지 않았습니다. (NODATA)');
      }
      throw WeatherException('기상청 API 오류: $resultMsg (코드: $resultCode)');
    }
  }

  KmaData _parseKmaData(DateTime kst, Map<String, dynamic> ncstJson, Map<String, dynamic> vilageJson) {
    final ncstItems = ncstJson['response']?['body']?['items']?['item'] as List<dynamic>? ?? const [];
    
    double? t1h;
    int? reh;
    double? rn1;
    double? wsd;
    int? pty;

    for (final item in ncstItems) {
      final category = item['category']?.toString();
      final valueStr = item['obsrValue']?.toString() ?? '';
      if (category == 'T1H') {
        t1h = double.tryParse(valueStr);
      } else if (category == 'REH') {
        reh = int.tryParse(valueStr);
      } else if (category == 'RN1') {
        rn1 = _parseKmaPrecipitation(valueStr);
      } else if (category == 'WSD') {
        wsd = double.tryParse(valueStr);
      } else if (category == 'PTY') {
        pty = int.tryParse(valueStr);
      }
    }

    final vilageItems = vilageJson['response']?['body']?['items']?['item'] as List<dynamic>? ?? const [];
    final Map<String, Map<String, String>> groupedForecast = {};

    for (final item in vilageItems) {
      final fcstDate = item['fcstDate']?.toString();
      final fcstTime = item['fcstTime']?.toString();
      final category = item['category']?.toString();
      final fcstValue = item['fcstValue']?.toString();

      if (fcstDate == null || fcstTime == null || category == null || fcstValue == null) {
        continue;
      }

      final key = '${fcstDate}_$fcstTime';
      groupedForecast.putIfAbsent(key, () => {})[category] = fcstValue;
    }

    final sortedKeys = groupedForecast.keys.toList()..sort();
    final List<HourlyWeather> hourlyForecasts = [];
    final Map<String, List<Map<String, String>>> dailyGroups = {};

    for (final key in sortedKeys) {
      final parts = key.split('_');
      final fcstDate = parts[0];
      final fcstTime = parts[1];
      final values = groupedForecast[key]!;

      dailyGroups.putIfAbsent(fcstDate, () => []).add(values);

      final year = int.parse(fcstDate.substring(0, 4));
      final month = int.parse(fcstDate.substring(4, 6));
      final day = int.parse(fcstDate.substring(6, 8));
      final hour = int.parse(fcstTime.substring(0, 2));
      final dateTime = DateTime(year, month, day, hour);

      if (dateTime.isBefore(kst.subtract(const Duration(hours: 1)))) {
        continue;
      }

      final tmp = double.tryParse(values['TMP'] ?? '') ?? 0.0;
      final sky = int.tryParse(values['SKY'] ?? '') ?? 1;
      final ptyVal = int.tryParse(values['PTY'] ?? '') ?? 0;
      final pop = int.tryParse(values['POP'] ?? '') ?? 0;

      final wmoCode = _mapKmaToWmoCode(sky, ptyVal);

      hourlyForecasts.add(HourlyWeather(
        time: dateTime,
        temperature: tmp,
        precipitationProbability: pop,
        weatherCode: wmoCode,
      ));
    }

    final limitedHourly = hourlyForecasts.take(12).toList();

    final List<DailyWeather> dailyForecasts = [];
    final sortedDates = dailyGroups.keys.toList()..sort();
    for (final dateStr in sortedDates) {
      final hourItems = dailyGroups[dateStr]!;
      
      double maxTemp = -999.0;
      double minTemp = 999.0;
      int maxPop = 0;

      for (final item in hourItems) {
        final tmp = double.tryParse(item['TMP'] ?? '');
        if (tmp != null) {
          if (tmp > maxTemp) maxTemp = tmp;
          if (tmp < minTemp) minTemp = tmp;
        }

        final tmn = double.tryParse(item['TMN'] ?? '');
        if (tmn != null && tmn < minTemp) minTemp = tmn;

        final tmx = double.tryParse(item['TMX'] ?? '');
        if (tmx != null && tmx > maxTemp) maxTemp = tmx;

        final pop = int.tryParse(item['POP'] ?? '') ?? 0;
        if (pop > maxPop) maxPop = pop;
      }

      final noonItem = hourItems.firstWhere(
        (item) => item['fcstTime'] == '1200' || item['fcstTime'] == '1300' || item['fcstTime'] == '1400',
        orElse: () => hourItems[hourItems.length ~/ 2],
      );

      final representativeSky = int.tryParse(noonItem['SKY'] ?? '') ?? 1;
      final representativePty = int.tryParse(noonItem['PTY'] ?? '') ?? 0;
      final wmoCode = _mapKmaToWmoCode(representativeSky, representativePty);

      final year = int.parse(dateStr.substring(0, 4));
      final month = int.parse(dateStr.substring(4, 6));
      final day = int.parse(dateStr.substring(6, 8));
      final date = DateTime(year, month, day);

      dailyForecasts.add(DailyWeather(
        date: date,
        maxTemperature: maxTemp == -999.0 ? 0.0 : maxTemp,
        minTemperature: minTemp == 999.0 ? 0.0 : minTemp,
        precipitationProbability: maxPop,
        weatherCode: wmoCode,
      ));
    }

    int currentSky = 1;
    if (sortedKeys.isNotEmpty) {
      final firstKey = sortedKeys.first;
      final firstVals = groupedForecast[firstKey]!;
      currentSky = int.tryParse(firstVals['SKY'] ?? '') ?? 1;
    }
    final currentWeatherCode = _mapKmaToWmoCode(currentSky, pty ?? 0);

    return KmaData(
      current: CurrentWeather(
        time: kst,
        temperature: t1h ?? 0.0,
        apparentTemperature: t1h ?? 0.0,
        humidity: reh ?? 0,
        precipitation: rn1 ?? 0.0,
        weatherCode: currentWeatherCode,
        windSpeed: wsd ?? 0.0,
        isDay: true,
      ),
      hourly: limitedHourly,
      daily: dailyForecasts,
    );
  }

  double _parseKmaPrecipitation(String str) {
    final clean = str.trim();
    if (clean == '강수없음' || clean == '적설없음' || clean == '0') {
      return 0.0;
    }
    if (clean.contains('미만')) {
      final numStr = clean.replaceAll(RegExp(r'[^0-9.]'), '');
      final val = double.tryParse(numStr) ?? 1.0;
      return val * 0.5;
    }
    if (clean.contains('이상')) {
      final numStr = clean.replaceAll(RegExp(r'[^0-9.]'), '');
      return double.tryParse(numStr) ?? 50.0;
    }
    if (clean.contains('~')) {
      final parts = clean.split('~');
      final first = double.tryParse(parts[0].replaceAll(RegExp(r'[^0-9.]'), ''));
      final second = double.tryParse(parts[1].replaceAll(RegExp(r'[^0-9.]'), ''));
      if (first != null && second != null) {
        return (first + second) / 2.0;
      }
    }
    final numStr = clean.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(numStr) ?? 0.0;
  }

  int _mapKmaToWmoCode(int sky, int pty) {
    if (pty == 0) {
      if (sky == 1) return 0; // 맑음
      if (sky == 3) return 2; // 구름많음
      if (sky == 4) return 3; // 흐림
    } else if (pty == 1 || pty == 5) {
      return 61; // 비 / 빗방울
    } else if (pty == 2 || pty == 6) {
      return 63; // 비/눈 / 빗방울눈날림 (진눈깨비)
    } else if (pty == 3 || pty == 7) {
      return 71; // 눈 / 눈날림
    } else if (pty == 4) {
      return 80; // 소나기
    }
    return 0;
  }

  double _calculateApparentTemperature(double t, double wsd, int rh) {
    final v = wsd * 3.6; // m/s -> km/h
    if (t <= 10.0 && v > 4.8) {
      return 13.12 + 0.6215 * t - 11.37 * math.pow(v, 0.16) + 0.3965 * t * math.pow(v, 0.16);
    }
    if (t >= 20.0) {
      return t + 0.5 * (t + 61.0 + ((t - 68.0) * 1.2) + (rh * 0.094));
    }
    return t;
  }

  WeatherForecast _mergeKmaForecast(WeatherForecast base, KmaData kma) {
    final currentTemp = kma.current.temperature;
    final currentWind = kma.current.windSpeed;
    final currentHumidity = kma.current.humidity;

    final currentApparent = _calculateApparentTemperature(currentTemp, currentWind, currentHumidity);

    final mergedCurrent = CurrentWeather(
      time: base.current.time,
      temperature: currentTemp,
      apparentTemperature: currentApparent,
      humidity: currentHumidity,
      precipitation: kma.current.precipitation,
      weatherCode: kma.current.weatherCode,
      windSpeed: currentWind * 3.6, // km/h 단위로 UI 전달
      isDay: base.current.isDay,
    );

    final mergedHourly = kma.hourly.isEmpty ? base.hourly : kma.hourly;

    final mergedDaily = List<DailyWeather>.from(base.daily);
    for (int i = 0; i < mergedDaily.length; i++) {
      final baseDate = mergedDaily[i].date;
      final kmaDaily = kma.daily.firstWhere(
        (kd) => kd.date.year == baseDate.year && kd.date.month == baseDate.month && kd.date.day == baseDate.day,
        orElse: () => mergedDaily[i],
      );

      if (kmaDaily != mergedDaily[i]) {
        mergedDaily[i] = DailyWeather(
          date: baseDate,
          maxTemperature: kmaDaily.maxTemperature,
          minTemperature: kmaDaily.minTemperature,
          precipitationProbability: kmaDaily.precipitationProbability,
          weatherCode: kmaDaily.weatherCode,
        );
      }
    }

    return WeatherForecast(
      city: base.city,
      current: mergedCurrent,
      hourly: mergedHourly,
      daily: mergedDaily,
      timezone: '기상청 (KMA) & Open-Meteo',
    );
  }

  Map<String, String> _getUltraSrtNcstDateTime(DateTime kst) {
    DateTime target = kst;
    if (kst.minute < 40) {
      target = kst.subtract(const Duration(hours: 1));
    }
    final dateStr = '${target.year}${target.month.toString().padLeft(2, '0')}${target.day.toString().padLeft(2, '0')}';
    final timeStr = '${target.hour.toString().padLeft(2, '0')}00';
    return {'base_date': dateStr, 'base_time': timeStr};
  }

  Map<String, String> _getVilageFcstDateTime(DateTime kst) {
    final List<int> baseHours = [2, 5, 8, 11, 14, 17, 20, 23];
    int baseHour = -1;
    for (int i = baseHours.length - 1; i >= 0; i--) {
      int bh = baseHours[i];
      if (kst.hour > bh || (kst.hour == bh && kst.minute >= 10)) {
        baseHour = bh;
        break;
      }
    }

    if (baseHour == -1) {
      final prevDay = kst.subtract(const Duration(days: 1));
      final dateStr = '${prevDay.year}${prevDay.month.toString().padLeft(2, '0')}${prevDay.day.toString().padLeft(2, '0')}';
      return {'base_date': dateStr, 'base_time': '2300'};
    } else {
      final dateStr = '${kst.year}${kst.month.toString().padLeft(2, '0')}${kst.day.toString().padLeft(2, '0')}';
      final timeStr = '${baseHour.toString().padLeft(2, '0')}00';
      return {'base_date': dateStr, 'base_time': timeStr};
    }
  }

  double _doubleAt(Map<String, dynamic> json, String key) {
    return (json[key] as num?)?.toDouble() ?? 0;
  }

  int _intAt(Map<String, dynamic> json, String key) {
    return (json[key] as num?)?.toInt() ?? 0;
  }
}

class WeatherException implements Exception {
  WeatherException(this.message);

  final String message;

  @override
  String toString() => message;
}
