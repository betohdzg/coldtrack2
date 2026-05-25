import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class ChartsScreen extends StatefulWidget {
  final String refrigeradorId;
  const ChartsScreen({super.key, required this.refrigeradorId});

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  String _currentRefriId = '';
  late DatabaseReference _sensoresRef;

  List<ChartData> _temperatureData = [];
  List<ChartData> _consumptionData = [];
  bool _isLoading = true;
  String _selectedPeriod = '10min';
  int _selectedType = 0;

  bool _isListening = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _currentRefriId = widget.refrigeradorId;
    _initFirebaseRef();
    _loadData();
    _listenToRealtimeUpdates();
    _startPeriodicRefresh();
  }

  void _initFirebaseRef() {
    _sensoresRef = FirebaseDatabase.instance
        .ref()
        .child('sensores')
        .child('refrigeradores')
        .child(_currentRefriId)
        .child('lecturas');
  }

  void _changeRefrigerador(String newRefriId) {
    if (_currentRefriId == newRefriId) return;
    setState(() {
      _currentRefriId = newRefriId;
      _isLoading = true;
      _initFirebaseRef();
      _loadData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _loadData();
    });
  }

  void _listenToRealtimeUpdates() {
    if (_isListening) return;
    _isListening = true;
    _sensoresRef.onChildAdded.listen((_) => _loadData());
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final snapshot = await _sensoresRef
          .orderByChild('Timestamp')
          .limitToLast(500)
          .get();

      if (snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final List<RawData> rawDataList = [];

        for (var entry in data.entries) {
          final reading = entry.value as Map<dynamic, dynamic>;
          final tsRaw = reading['Timestamp']?.toString();
          DateTime? dateTime;
          if (tsRaw != null && tsRaw.isNotEmpty) {
            try {
              final cleaned = tsRaw.replaceAll(RegExp(r'^[A-Za-z]+ '), '').trim();
              dateTime = DateFormat('dd.MM.yyyy -- HH:mm:ss').parse(cleaned);
            } catch (_) {
              dateTime = DateTime.now();
            }
          }
          if (dateTime != null) {
            final temp = double.tryParse(reading['inTemp']?.toString() ?? '0') ?? 0.0;
            final consumo = double.tryParse(reading['ConsumoElectrico']?.toString() ?? '0') ?? 0.0;
            rawDataList.add(RawData(dateTime, temp, consumo));
          }
        }

        rawDataList.sort((a, b) => a.date.compareTo(b.date));

        if (mounted) {
          setState(() {
            _temperatureData = _processData(rawDataList, isTemperature: true);
            _consumptionData = _processData(rawDataList, isTemperature: false);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error cargando datos: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<ChartData> _processData(List<RawData> raw, {required bool isTemperature}) {
    if (raw.isEmpty) return [];
    final ahora = DateTime.now();

    switch (_selectedPeriod) {
      case '10min':
        final hace10Min = ahora.subtract(const Duration(minutes: 10));
        final datosFiltrados = raw.where((item) => item.date.isAfter(hace10Min)).toList();
        if (datosFiltrados.isEmpty) return [];

        Map<String, List<double>> grouped = {};
        Map<String, DateTime> dateMap = {};
        for (var item in datosFiltrados) {
          final key = DateFormat('HH:mm').format(item.date);
          if (!grouped.containsKey(key)) {
            grouped[key] = [];
            dateMap[key] = item.date;
          }
          final value = isTemperature ? item.temperature : item.consumption;
          grouped[key]!.add(value);
        }
        final result = <ChartData>[];
        for (var entry in grouped.entries) {
          final avg = entry.value!.reduce((a, b) => a + b) / entry.value!.length;
          result.add(ChartData(dateMap[entry.key]!, avg));
        }
        result.sort((a, b) => a.date.compareTo(b.date));
        return result;

      case 'Día':
        final inicioDia = DateTime(ahora.year, ahora.month, ahora.day);
        final datosFiltrados = raw.where((item) => item.date.isAfter(inicioDia)).toList();
        if (datosFiltrados.isEmpty) return [];

        Map<String, List<double>> grouped = {};
        Map<String, DateTime> dateMap = {};
        for (var item in datosFiltrados) {
          final minutes = item.date.minute;
          final roundedMinute = (minutes / 10).floor() * 10;
          final groupDate = DateTime(
            item.date.year, item.date.month, item.date.day,
            item.date.hour, roundedMinute,
          );
          final key = DateFormat('HH:mm').format(groupDate);
          if (!grouped.containsKey(key)) {
            grouped[key] = [];
            dateMap[key] = groupDate;
          }
          final value = isTemperature ? item.temperature : item.consumption;
          grouped[key]!.add(value);
        }
        final result = <ChartData>[];
        for (var entry in grouped.entries) {
          final avg = entry.value!.reduce((a, b) => a + b) / entry.value!.length;
          result.add(ChartData(dateMap[entry.key]!, avg));
        }
        result.sort((a, b) => a.date.compareTo(b.date));
        return result;

      case 'Semana':
        final hace7Dias = ahora.subtract(const Duration(days: 7));
        final datosFiltrados = raw.where((item) => item.date.isAfter(hace7Dias)).toList();
        if (datosFiltrados.isEmpty) return [];

        Map<String, List<double>> grouped = {};
        Map<String, DateTime> dateMap = {};
        for (var item in datosFiltrados) {
          final key = DateFormat('dd/MM').format(item.date);
          if (!grouped.containsKey(key)) {
            grouped[key] = [];
            dateMap[key] = DateTime(item.date.year, item.date.month, item.date.day);
          }
          final value = isTemperature ? item.temperature : item.consumption;
          grouped[key]!.add(value);
        }
        final result = <ChartData>[];
        for (var entry in grouped.entries) {
          final avg = entry.value!.reduce((a, b) => a + b) / entry.value!.length;
          result.add(ChartData(dateMap[entry.key]!, avg));
        }
        result.sort((a, b) => a.date.compareTo(b.date));
        return result;

      default: return [];
    }
  }

  void _changePeriod(String period) {
    setState(() {
      _selectedPeriod = period;
      _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = _selectedType == 0 ? _temperatureData : _consumptionData;
    final color = _selectedType == 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Estadísticas', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        centerTitle: true,
        actions: [
          // Selector de refrigerador en el AppBar
          PopupMenuButton<String>(
            icon: const Icon(Icons.kitchen_outlined),
            tooltip: 'Seleccionar refrigerador',
            onSelected: _changeRefrigerador,
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'ref01', child: Text('Refrigerador Principal')),
              const PopupMenuItem(value: 'ref02', child: Text('Congelador Trasero')),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Selectores de período y tipo (estilo original)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
                    ],
                  ),
                  child: Row(
                    children: [
                      '10min',
                      'Día',
                      'Semana',
                    ].map((p) => _buildPeriodButton(p)).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
                    ],
                  ),
                  child: Row(
                    children: [
                      _buildTypeButton('🌡️ Temperatura', 0),
                      _buildTypeButton('⚡ Consumo', 1),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : data.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.show_chart_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text('No hay datos disponibles', style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildModernChart(data, color),
                        const SizedBox(height: 16),
                        _buildStatsRow(data, color),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String period) {
    final isSelected = _selectedPeriod == period;
    String displayText;
    if (period == '10min') displayText = '10 min';
    else if (period == 'Día') displayText = 'Día';
    else displayText = 'Semana';

    return Expanded(
      child: GestureDetector(
        onTap: () => _changePeriod(period),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF00ACC1) : Colors.transparent,
            borderRadius: BorderRadius.circular(40),
          ),
          child: Text(
            displayText,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[700],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeButton(String label, int index) {
    final isSelected = _selectedType == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF00ACC1) : Colors.transparent,
            borderRadius: BorderRadius.circular(40),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[700],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernChart(List<ChartData> data, Color color) {
    final spots = data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList();
    final maxV = data.isNotEmpty ? data.map((e) => e.value).reduce((a, b) => a > b ? a : b) : 0.0;
    final minV = data.isNotEmpty ? data.map((e) => e.value).reduce((a, b) => a < b ? a : b) : 0.0;

    final bool isTemperature = _selectedType == 0;
    final double yInterval = isTemperature ? 0.5 : 20;
    final int leftReservedSize = isTemperature ? 55 : 65;
    final range = maxV - minV;
    final yMin = (minV - range * 0.1).clamp(0, double.infinity).toDouble();
    final yMax = (maxV + range * 0.1).toDouble();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isTemperature ? 'Temperatura Interior' : 'Consumo Eléctrico',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(20)),
                  child: Text('📊 ${spots.length} puntos', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 280,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: yInterval,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[200]!, strokeWidth: 1, dashArray: [5, 5]),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: leftReservedSize.toDouble(),
                        interval: yInterval,
                        getTitlesWidget: (value, meta) {
                          if (isTemperature) {
                            if (value == value.toInt() || (value * 2) == (value * 2).toInt()) {
                              return Text('${value.toStringAsFixed(1)}°C', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)));
                            }
                          } else {
                            if (value == value.toInt()) {
                              return Text('${value.toInt()} kWh', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)));
                            }
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 65,
                        interval: _getXInterval(data.length),
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= data.length) return const Text('');
                          return Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Transform.rotate(angle: -0.3, child: Text(_formatLabel(data[index].date), style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)))),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: color,
                      barWidth: 3.5,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                          radius: 5,
                          color: Colors.white,
                          strokeWidth: 2.5,
                          strokeColor: color,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(colors: [color.withOpacity(0.3), color.withOpacity(0.02)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                      ),
                    ),
                  ],
                  minY: yMin,
                  maxY: yMax,
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                        final index = spot.x.toInt();
                        return LineTooltipItem(
                          isTemperature
                              ? '${spot.y.toStringAsFixed(1)}°C\n${_formatLabel(data[index].date)}'
                              : '${spot.y.toStringAsFixed(0)} kWh\n${_formatLabel(data[index].date)}',
                          const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        );
                      }).toList(),
                      getTooltipColor: (touchedSpot) => const Color(0xFF1E293B),
                    ),
                    handleBuiltInTouches: true,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _getXInterval(int pointCount) {
    if (pointCount <= 6) return 1;
    if (pointCount <= 12) return 2;
    return (pointCount / 6).ceil().toDouble();
  }

  Widget _buildStatsRow(List<ChartData> data, Color color) {
    if (data.isEmpty) return const SizedBox();
    final values = data.map((e) => e.value).toList();
    final max = values.reduce((a, b) => a > b ? a : b);
    final min = values.reduce((a, b) => a < b ? a : b);
    final avg = values.reduce((a, b) => a + b) / values.length;

    return Row(
      children: [
        _buildStatCard('📈 Máximo', _selectedType == 0 ? '${max.toStringAsFixed(1)}°C' : '${max.toInt()} kWh', color),
        const SizedBox(width: 12),
        _buildStatCard('📉 Mínimo', _selectedType == 0 ? '${min.toStringAsFixed(1)}°C' : '${min.toInt()} kWh', color),
        const SizedBox(width: 12),
        _buildStatCard('📊 Promedio', _selectedType == 0 ? '${avg.toStringAsFixed(1)}°C' : '${avg.toInt()} kWh', color),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  String _formatLabel(DateTime date) {
    switch (_selectedPeriod) {
      case '10min': return DateFormat('HH:mm').format(date);
      case 'Día': return DateFormat('HH:mm').format(date);
      case 'Semana': return DateFormat('dd/MM').format(date);
      default: return DateFormat('HH:mm').format(date);
    }
  }
}

// Modelos
class RawData {
  final DateTime date;
  final double temperature;
  final double consumption;
  RawData(this.date, this.temperature, this.consumption);
}

class ChartData {
  final DateTime date;
  final double value;
  ChartData(this.date, this.value);
}