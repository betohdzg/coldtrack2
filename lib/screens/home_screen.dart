import 'package:carnitrack2/models/alert.dart';
import 'package:carnitrack2/screens/alerts_screen.dart';
import 'package:carnitrack2/screens/charts_screen.dart';
import 'package:carnitrack2/screens/login_screen.dart';
import 'package:carnitrack2/services/notification_service.dart';
import 'package:carnitrack2/screens/settings_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:carnitrack2/screens/sensores_screen.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final Set<String> _processedAlertIds = {};
  final List<String> _refIds = ['ref01', 'ref02'];

  List<Map<String, dynamic>> _refrigeradores = [];
  bool _isLoadingDashboard = true;

  final List<AppAlert> _alerts = [];
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    _listenToAllRefrigeradoresRealTime();
    _listenToAlertasDeTodos();
    _loadInitialData(); // ← nuevo
  }

  Future<void> _debugPrintAllReadings() async {
    for (String refId in _refIds) {
      final snapshot = await _dbRef
          .child('sensores/refrigeradores/$refId/lecturas')
          .get();
      if (snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        print('📚 Todas las lecturas para $refId:');
        data.forEach((key, value) {
          print('  $key -> Timestamp: ${value['Timestamp']}');
        });
      } else {
        print('⚠️ No hay lecturas para $refId');
      }
    }
  }

  // ==================== ACTUALIZACIÓN EN TIEMPO REAL ====================
  Future<void> _loadInitialData() async {
    for (String refId in _refIds) {
      final snapshot = await _dbRef
          .child('sensores/refrigeradores/$refId/lecturas')
          .get();
      if (snapshot.value == null) continue;

      final data = snapshot.value as Map<dynamic, dynamic>;
      Map<String, dynamic>? ultimaLectura;
      DateTime? ultimoTimestamp;

      for (var entry in data.entries) {
        final lectura = Map<String, dynamic>.from(entry.value as Map);
        final tsStr = lectura['Timestamp']?.toString();
        if (tsStr == null || tsStr.isEmpty) continue;

        try {
          final cleaned = tsStr.replaceAll(RegExp(r'^[A-Za-z]+ '), '').trim();
          final fecha = DateFormat('dd.MM.yyyy -- HH:mm:ss').parse(cleaned);
          if (ultimoTimestamp == null || fecha.isAfter(ultimoTimestamp)) {
            ultimoTimestamp = fecha;
            ultimaLectura = lectura;
          }
        } catch (e) {}
      }

      if (ultimaLectura != null && ultimoTimestamp != null) {
        final temp =
            double.tryParse(ultimaLectura['inTemp']?.toString() ?? '0') ?? 0.0;
        final nuevoRefri = {
          'id': refId,
          'nombre': _nombreRefri(refId),
          'tempInterior': temp.toStringAsFixed(1),
          'consumo': ultimaLectura['ConsumoElectrico']?.toString() ?? '0',
          'mantenimiento': ultimaLectura['falla_detectada'] == true ? '1' : '0',
          'puerta': ultimaLectura['DoorStatus'] == 'DoorOPEN'
              ? 'OPEN'
              : 'CLOSED',
          'compresor': ultimaLectura['CompressorStatus'] == 'CompressorON'
              ? 'ON'
              : 'OFF',
          'power': 'ON',
          'humedad': ultimaLectura['InHumid']?.toString() ?? 'N/A',
          'timestamp': ultimoTimestamp.toIso8601String(),
        };
        // ✅ Actualiza si ya existe, agrega si es nuevo
        setState(() {
          final index = _refrigeradores.indexWhere((r) => r['id'] == refId);
          if (index != -1) {
            _refrigeradores[index] = nuevoRefri;
          } else {
            _refrigeradores.add(nuevoRefri);
          }
        });
      }
    }
    setState(() => _isLoadingDashboard = false);
  }

  void _listenToAllRefrigeradoresRealTime() {
    for (String refId in _refIds) {
      _dbRef
          .child('sensores/refrigeradores/$refId/lecturas')
          .onChildAdded
          .listen((event) {
            final lectura = Map<String, dynamic>.from(
              event.snapshot.value as Map,
            );
            final tsStr = lectura['Timestamp']?.toString();
            if (tsStr == null || tsStr.isEmpty) return;

            DateTime? fecha;
            try {
              final cleaned = tsStr
                  .replaceAll(RegExp(r'^[A-Za-z]+ '), '')
                  .trim();
              fecha = DateFormat('dd.MM.yyyy -- HH:mm:ss').parse(cleaned);
            } catch (e) {
              return;
            }
            if (fecha == null) return;

            // Verificar si ya tenemos un dato más reciente
            final index = _refrigeradores.indexWhere((r) => r['id'] == refId);
            bool necesitaActualizar = false;
            if (index == -1) {
              necesitaActualizar = true;
            } else {
              final fechaExistente = DateTime.tryParse(
                _refrigeradores[index]['timestamp'] ?? '',
              );
              if (fechaExistente == null || fecha.isAfter(fechaExistente)) {
                necesitaActualizar = true;
              }
            }

            if (necesitaActualizar) {
              final temp =
                  double.tryParse(lectura['inTemp']?.toString() ?? '0') ?? 0.0;
              final nuevoRefri = {
                'id': refId,
                'nombre': _nombreRefri(refId),
                'tempInterior': temp.toStringAsFixed(1),
                'consumo': lectura['ConsumoElectrico']?.toString() ?? '0',
                'mantenimiento': lectura['falla_detectada'] == true ? '1' : '0',
                'puerta': lectura['DoorStatus'] == 'DoorOPEN'
                    ? 'OPEN'
                    : 'CLOSED',
                'compresor': lectura['CompressorStatus'] == 'CompressorON'
                    ? 'ON'
                    : 'OFF',
                'power': 'ON',
                'humedad': lectura['InHumid']?.toString() ?? 'N/A',
                'timestamp': fecha.toIso8601String(),
              };
              setState(() {
                if (index != -1) {
                  _refrigeradores[index] = nuevoRefri;
                } else {
                  _refrigeradores.add(nuevoRefri);
                }
              });
            }
          });
    }
  }

  void _setLoadingFalse() {
    if (_isLoadingDashboard) {
      setState(() => _isLoadingDashboard = false);
    }
  }

  String _nombreRefri(String refId) =>
      refId == 'ref01' ? 'Refrigerador Principal' : 'Congelador Trasero';

  // ==================== ALERTAS ====================
  void _listenToAlertasDeTodos() {
    for (String refId in _refIds) {
      _dbRef
          .child('sensores')
          .child('refrigeradores')
          .child(refId)
          .child('alertas')
          .onChildAdded
          .listen((event) {
            final alertaId = event.snapshot.key;
            if (alertaId == null ||
                _processedAlertIds.contains('$refId-$alertaId'))
              return;

            _processedAlertIds.add('$refId-$alertaId');
            final data = Map<String, dynamic>.from(event.snapshot.value as Map);
            final nuevaAlerta = AppAlert.fromFirebase(data, alertaId, refId);

            setState(() {
              _alerts.insert(0, nuevaAlerta);
            });

            NotificationService.showNotification(
              id: DateTime.now().millisecondsSinceEpoch % 100000,
              title: nuevaAlerta.title,
              body: '${nuevaAlerta.subtitle} (${_nombreRefri(refId)})',
            );
          });
    }
  }

  // Necesario para AlertsScreen
  void _updateAlerts() {
    setState(() {});
  }

  // Necesario para RefreshIndicator del Dashboard
  Future<void> _refreshDashboard() async {
    // La escucha en tiempo real ya actualiza, pero forzamos un pequeño refresh visual
    setState(() {});
  }

  int get unreadAlerts => _alerts.where((a) => !a.isRead).length;

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 26, 139, 161),
        foregroundColor: Colors.white,
        elevation: 2,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              child: Image.asset(
                'assets/icon/coldtrack.png',
                height: 86,
                width: 56,
              ),
            ),
            const SizedBox(width: 3),
            const Text(
              'ColdTrack',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          Builder(
            builder: (context) => Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.menu, size: 28),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
                if (unreadAlerts > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        unreadAlerts > 99 ? '99+' : unreadAlerts.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF00ACC1)),
              child: Text(
                'Menú',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Inicio'),
              selected: _selectedIndex == 0,
              onTap: () => _onItemTapped(0),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Historial'),
              selected: _selectedIndex == 1,
              onTap: () => _onItemTapped(1),
            ),
            ListTile(
              leading: const Icon(Icons.show_chart),
              title: const Text('Gráficas'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ChartsScreen(refrigeradorId: 'ref01'),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Alertas'),
              selected: _selectedIndex == 2,
              trailing: unreadAlerts > 0
                  ? Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        unreadAlerts.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : null,
              onTap: () => _onItemTapped(2),
            ),
            ExpansionTile(
              leading: const Icon(Icons.settings),
              title: const Text('Ajustes'),
              childrenPadding: const EdgeInsets.only(left: 20),
              children: [
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Mi Perfil'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    'Cerrar Sesión',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // Dentro del IndexedStack:
          DashboardContent(
            key: ValueKey(_refrigeradores.length),
            refrigeradores: _refrigeradores,
            isLoading: _isLoadingDashboard,
            onRefresh: _refreshDashboard,
          ),
          const SensoresScreen(refrigeradorId: 'ref01'),
          AlertsScreen(
            alerts: _alerts,
            onAlertsUpdated: _updateAlerts, // ← TAMBIÉN FALTABA
          ),
          const ChartsScreen(refrigeradorId: 'ref01'),
          const SettingsScreen(),
        ],
      ),
    );
  }
}

/// ===================== TARJETAS VERTICALES ESTILO HISTORIAL (MODERNAS) =====================
class DashboardContent extends StatelessWidget {
  final List<Map<String, dynamic>> refrigeradores;
  final bool isLoading;
  final VoidCallback onRefresh;

  const DashboardContent({
    super.key,
    required this.refrigeradores,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mis Refrigeradores',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${refrigeradores.length} activos',
              style: TextStyle(fontSize: 15, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),

            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (refrigeradores.isEmpty)
              const Center(child: Text('No hay refrigeradores registrados'))
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: refrigeradores.length,
                itemBuilder: (context, index) =>
                    _buildHistoryStyleCard(context, refrigeradores[index]),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryStyleCard(
    BuildContext context,
    Map<String, dynamic> refri,
  ) {
    final temp =
        double.tryParse(refri['tempInterior']?.toString() ?? '0') ?? 0.0;
    final tempColor = temp > 5
        ? Colors.red
        : (temp >= 0 && temp <= 4 ? Colors.green : Colors.orange);
    final humedad = refri['humedad'] ?? '--';
    final consumo = refri['consumo'] ?? '0';
    final puertaEstado = refri['puerta'] == 'OPEN' ? 'ABIERTA' : 'CERRADA';
    final compresorEstado = refri['compresor'] == 'ON' ? 'ON' : 'OFF';

    final doorColor = puertaEstado == 'ABIERTA' ? Colors.red : Colors.green;
    final compColor = compresorEstado == 'ON' ? Colors.orange : Colors.blue;

    return Card(
      elevation: 2, // ✅ valor fijo (sin isViewed)
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          // Acción opcional al tocar la tarjeta
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabecera: nombre e icono
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      refri['nombre'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.kitchen, color: tempColor, size: 28),
                ],
              ),
              const SizedBox(height: 16),
              // Temperatura
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: tempColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.thermostat, color: tempColor, size: 32),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${refri['tempInterior']}°C',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: tempColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Humedad
              Row(
                children: [
                  Icon(Icons.water_drop_outlined, size: 22, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    'Humedad: ${_formatHumedad(humedad)}%',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              // Consumo
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.electric_bolt, size: 22, color: Colors.amber),
                  const SizedBox(width: 8),
                  Text(
                    'Consumo: $consumo kWh',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Indicadores de estado
              Row(
                children: [
                  _buildStatusIcon(Icons.door_back_door, doorColor),
                  const SizedBox(width: 16),
                  _buildStatusIcon(Icons.settings, compColor),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 20),
              // Botones
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ChartsScreen(refrigeradorId: refri['id']),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: tempColor,
                        side: BorderSide(color: tempColor, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Gráfico'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                SensoresScreen(refrigeradorId: refri['id']),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: tempColor,
                        side: BorderSide(color: tempColor, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Historial'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  String _formatHumedad(String humedad) {
    try {
      final h = double.parse(humedad);
      return h.toStringAsFixed(1);
    } catch (_) {
      return humedad;
    }
  }
}
