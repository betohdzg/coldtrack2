import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SensoresScreen extends StatefulWidget {
  final String refrigeradorId;
  const SensoresScreen({super.key, required this.refrigeradorId});

  @override
  State<SensoresScreen> createState() => _SensoresScreenState();
}

class _SensoresScreenState extends State<SensoresScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: const Color(0xFF00ACC1),
                borderRadius: BorderRadius.circular(40),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey[700],
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: const [
                Tab(text: 'Refrigerador Principal'),
                Tab(text: 'Congelador Trasero'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _HistoryTab(refId: 'ref01', nombre: 'Refrigerador Principal'),
                _HistoryTab(refId: 'ref02', nombre: 'Congelador Trasero'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Widget independiente para cada pestaña
class _HistoryTab extends StatefulWidget {
  final String refId;
  final String nombre;

  const _HistoryTab({required this.refId, required this.nombre});

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab>
    with AutomaticKeepAliveClientMixin {
  final Set<String> _viewedReadings = {};

  @override
  bool get wantKeepAlive => true;

  String _getMantenimientoMessage(Map<String, dynamic> lectura) {
    final fallaDetectada = lectura['falla_detectada'] == true;
    final tipoFalla = lectura['tipo_falla']?.toString() ?? '';
    if (fallaDetectada) {
      switch (tipoFalla) {
        case 'SOBRECALENTAMIENTO':
          return '🔴 SOBRECALENTAMIENTO';
        case 'VIBRACIÓN EXCESIVA':
          return '📳 VIBRACIÓN EXCESIVA';
        case 'CONSUMO ELÉCTRICO ANORMAL':
          return '⚡ CONSUMO ANORMAL';
        case 'PUERTA ABIERTA PROLONGADA':
          return '🚪 PUERTA ABIERTA';
        case 'HUMEDAD ANORMAL':
          return '💧 HUMEDAD ANORMAL';
        default:
          return '⚠️ FALLA DETECTADA';
      }
    }
    return '✅ Funcionando correctamente';
  }

  Color _getMantenimientoColor(Map<String, dynamic> lectura) =>
      lectura['falla_detectada'] == true ? Colors.red : Colors.green;

  void _startAutoDeleteTimer(String readingId) {
    Future.delayed(const Duration(minutes: 3), () {
      if (_viewedReadings.contains(readingId)) {
        FirebaseDatabase.instance
            .ref()
            .child('sensores/refrigeradores/${widget.refId}/lecturas')
            .child(readingId)
            .remove()
            .then((_) => setState(() => _viewedReadings.remove(readingId)));
      }
    });
  }

  void _showDetailDialog(
    BuildContext context,
    String fecha,
    String hora,
    double inTemp,
    String inHumid,
    String consumo,
    String vibration,
    String door,
    bool fallaDetectada,
    String tipoFalla,
    Color mantenimientoColor,
    String mantenimientoMsg,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              fallaDetectada ? Icons.warning : Icons.check_circle,
              color: mantenimientoColor,
            ),
            const SizedBox(width: 8),
            Text(fallaDetectada ? '⚠️ Alerta' : '✅ Normal'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _DetailRow('📅 Fecha', '$fecha $hora'),
              const Divider(),
              _DetailRow('🌡️ Temperatura', '${inTemp.toStringAsFixed(1)} °C'),
              _DetailRow('💧 Humedad Interior', '$inHumid %'),
              _DetailRow('⚡ Consumo', '$consumo kWh'),
              _DetailRow('📳 Vibración', vibration),
              _DetailRow('🚪 Puerta', door),
              const Divider(),
              _DetailRow(
                '🔧 Estado',
                fallaDetectada ? '⚠️ FALLA DETECTADA' : '✅ NORMAL',
                color: mantenimientoColor,
              ),
              if (fallaDetectada) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: mantenimientoColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🔴 Tipo de falla:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: mantenimientoColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tipoFalla,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: mantenimientoColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF00ACC1),
            ),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  // ✅ Convierte el string del timestamp a DateTime real
  DateTime _parseTimestamp(String tsStr) {
    try {
      final cleaned = tsStr.replaceAll(RegExp(r'^[A-Za-z]+ '), '').trim();
      return DateFormat('dd.MM.yyyy -- HH:mm:ss').parse(cleaned);
    } catch (e) {
      return DateTime(2000, 1, 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ref = FirebaseDatabase.instance.ref().child(
      'sensores/refrigeradores/${widget.refId}/lecturas',
    );

    return StreamBuilder<DatabaseEvent>(
      stream: ref.onValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No hay lecturas registradas aún.'),
              ],
            ),
          );
        }

        final dataMap = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
        // ✅ Ordenar por fecha real (no por string)
        final lecturasList = dataMap.entries.toList()
          ..sort((a, b) {
            final tsA = (a.value as Map)['Timestamp']?.toString() ?? '';
            final tsB = (b.value as Map)['Timestamp']?.toString() ?? '';
            final dateA = _parseTimestamp(tsA);
            final dateB = _parseTimestamp(tsB);
            return dateB.compareTo(dateA); // Más reciente primero
          });
        final ultimas20 = lecturasList.take(20).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: ultimas20.length,
          itemBuilder: (context, index) {
            final entry = ultimas20[index];
            final id = entry.key as String;
            final d = Map<String, dynamic>.from(entry.value as Map);
            final isViewed = _viewedReadings.contains(id);

            final compressor = d['CompressorStatus']?.toString() ?? 'N/A';
            final consumo = d['ConsumoElectrico']?.toString() ?? 'N/A';
            final door = d['DoorStatus']?.toString() ?? 'N/A';
            final inHumid = d['InHumid']?.toString() ?? 'N/A';
            final vibration = d['Vibration']?.toString() ?? 'N/A';
            final inTemp =
                double.tryParse(d['inTemp']?.toString() ?? '0') ?? 0.0;

            final mantenimientoMsg = _getMantenimientoMessage(d);
            final mantenimientoColor = _getMantenimientoColor(d);
            final fallaDetectada = d['falla_detectada'] == true;
            final tipoFalla = d['tipo_falla']?.toString() ?? '';

            String fecha = 'Sin fecha';
            String hora = '';
            final tsRaw = d['Timestamp']?.toString();
            if (tsRaw != null && tsRaw.isNotEmpty) {
              try {
                final cleaned = tsRaw
                    .replaceAll(RegExp(r'^[A-Za-z]+ '), '')
                    .trim();
                final date = DateFormat(
                  'dd.MM.yyyy -- HH:mm:ss',
                ).parse(cleaned);
                fecha = DateFormat('dd/MM/yyyy').format(date);
                hora = DateFormat('HH:mm:ss').format(date);
              } catch (e) {
                fecha = tsRaw;
              }
            }

            Color tempColor;
            if (inTemp > 5)
              tempColor = Colors.red;
            else if (inTemp >= 0 && inTemp <= 4)
              tempColor = Colors.green;
            else
              tempColor = Colors.orange;

            final doorColor = door.contains('OPEN') ? Colors.red : Colors.green;
            final compColor = compressor.contains('ON')
                ? Colors.orange
                : Colors.blue;

            return Card(
              elevation: isViewed ? 1 : 3,
              margin: const EdgeInsets.only(bottom: 12),
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: isViewed
                    ? BorderSide.none
                    : const BorderSide(color: Color(0xFF00ACC1), width: 1),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  if (!isViewed) {
                    setState(() => _viewedReadings.add(id));
                    _startAutoDeleteTimer(id);
                  }
                  _showDetailDialog(
                    context,
                    fecha,
                    hora,
                    inTemp,
                    inHumid,
                    consumo,
                    vibration,
                    door,
                    fallaDetectada,
                    tipoFalla,
                    mantenimientoColor,
                    mantenimientoMsg,
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              widget.nombre,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xFF1E293B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            hora,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: tempColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.thermostat,
                              color: tempColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${inTemp.toStringAsFixed(1)}°C',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: tempColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.electric_bolt,
                                      size: 12,
                                      color: Colors.amber,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$consumo kWh',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              _buildStatusIcon(Icons.door_back_door, doorColor),
                              const SizedBox(height: 4),
                              _buildStatusIcon(Icons.settings, compColor),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: mantenimientoColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: mantenimientoColor.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              fallaDetectada
                                  ? Icons.warning_amber
                                  : Icons.check_circle,
                              color: mantenimientoColor,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                mantenimientoMsg,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: mantenimientoColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            fecha,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                            ),
                          ),
                          if (!isViewed)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'NUEVA',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 14),
    );
  }

  Widget _DetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
