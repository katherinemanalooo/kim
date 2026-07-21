import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:http/http.dart' as http;

const Color kDefaultAccent = Color(0xFF32D74B);

// GlassCard/GlassListTile render their child content through the
// package's own shader pipeline, which doesn't reliably resolve
// CupertinoDynamicColor values (CupertinoColors.label, .systemGrey,
// etc.) against our in-app Dark Mode toggle — those kept rendering
// as if the OS-level brightness was in charge instead. These two
// helpers sidestep that entirely by reading our own AppState-driven
// CupertinoTheme brightness and returning a concrete, already-resolved
// Color, so text is always readable in both modes regardless of how
// the glass widgets paint their children.
Color primaryTextColor(BuildContext context) {
  final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
  return isDark ? CupertinoColors.white : CupertinoColors.black;
}

Color secondaryTextColor(BuildContext context) {
  final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
  return isDark ? const Color(0xFFAEAEB2) : const Color(0xFF6D6D72);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize();
  AppState.instance.checkConnection();
  runApp(
    LiquidGlassWidgets.wrap(
      child: const MyApp(),
    ),
  );
}
/// Single shared source of truth for the whole app: connection status,
/// sensor readings, LED state, and user settings. Every screen listens
/// to the pieces it needs via ValueListenableBuilder / AnimatedBuilder.
class AppState {
  AppState._internal();
  static final AppState instance = AppState._internal();

  // ESP32 — these two endpoints must match esp32_led_ultrasonic.ino exactly.
  static const String espBaseUrl = "http://192.168.4.1";
  static const String distanceEndpoint = "$espBaseUrl/api/distance";
  static const String ledEndpoint = "$espBaseUrl/api/status/";
  static const String fanEndpoint = "$espBaseUrl/api/fan/";
  // Connectivity
  final ValueNotifier<bool> isConnected = ValueNotifier(false);
  final ValueNotifier<bool> sensorOk = ValueNotifier(false);

  // Ultrasonic reading (always stored in cm; converted for display only)
  final ValueNotifier<double?> distanceCm = ValueNotifier(null);

  // LED
  final ValueNotifier<bool> ledOn = ValueNotifier(false);
  final ValueNotifier<bool> fanOn = ValueNotifier(false);

  // Settings
  final ValueNotifier<bool> darkMode = ValueNotifier(true);
  final ValueNotifier<bool> metricSystem = ValueNotifier(true); // true = cm
  final ValueNotifier<Color> themeColor = ValueNotifier(kDefaultAccent);

  Timer? _pollTimer;

  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) => fetchDistance());
    fetchDistance();
  }

  // GET /api/distance — polls the ultrasonic reading every 1s.
  Future<void> fetchDistance() async {
    try {
      final response = await http
          .get(Uri.parse(distanceEndpoint))
          .timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        isConnected.value = true;
        final data = jsonDecode(response.body);
        final d = data['distance'];
        if (data['success'] == true && d != null) {
          distanceCm.value = (d as num).toDouble();
          sensorOk.value = true;
        } else {
          _clearSensorReading();
        }
      } else {
        isConnected.value = false;
        _clearSensorReading();
      }
    } catch (_) {
      isConnected.value = false;
      _clearSensorReading();
    }
  }
  Future<void> checkConnection() async {

    try {

      final response = await http
          .get(Uri.parse(espBaseUrl))
          .timeout(
          const Duration(seconds: 2)
      );


      if(response.statusCode == 200){
        isConnected.value = true;
      }

    }

    catch(e){

      isConnected.value = false;

    }

  }
  // Wipes the displayed distance back to "—  —  —" — called whenever
  // the ultrasonic read fails OR the ESP32 itself is unreachable, so
  // the dashboard never shows a stale reading from before the drop.
  void _clearSensorReading() {
    sensorOk.value = false;
    distanceCm.value = null;
  }

  // POST /api/status/ — sets the LED; ESP32 also answers this route on GET.
  Future<void> setLed(bool on) async {
    final previous = ledOn.value;
    ledOn.value = on; // optimistic update so the tap feels instant
    try {
      final response = await http.post(
        Uri.parse(ledEndpoint),
        body: {"state": on ? "on" : "off"},
      ).timeout(const Duration(seconds: 3));
      debugPrint(response.body);
      isConnected.value = true;
    } catch (_) {
      isConnected.value = false;
      ledOn.value = previous; // revert if the ESP32 didn't respond
    }
  }
  Future<void> setFan(bool on) async {
    final previous = fanOn.value;
    fanOn.value = on;

    try {
      final response = await http.post(
        Uri.parse(fanEndpoint),
        body: {
          "state": on ? "on" : "off",
        },
      ).timeout(const Duration(seconds: 3));

      debugPrint(response.body);
      isConnected.value = true;
    } catch (_) {
      isConnected.value = false;
      fanOn.value = previous;
    }
  }

  double cmToInches(double cm) => cm / 2.54;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([AppState.instance.darkMode, AppState.instance.themeColor]),
      builder: (context, _) {
        final isDark = AppState.instance.darkMode.value;
        final accent = AppState.instance.themeColor.value;
        return CupertinoApp(
          debugShowCheckedModeBanner: false,
          theme: CupertinoThemeData(
            brightness: isDark ? Brightness.dark : Brightness.light,
            primaryColor: accent,
          ),
          home: const RootTabs(),
        );
      },
    );
  }
}

class RootTabs extends StatefulWidget {
  const RootTabs({super.key});

  @override
  State<RootTabs> createState() => _RootTabsState();
}

class _RootTabsState extends State<RootTabs> {
  int selectedIndex = 0;
  final List<Widget> pages = [
    const HomePage(),
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      bottomBar: GlassTabBar.bottom(
        settings: const LiquidGlassSettings(chromaticAberration: 1),
        tabs: const [
          GlassTab(icon: FaIcon(FontAwesomeIcons.house), label: 'Home'),
          GlassTab(icon: Icon(CupertinoIcons.settings), label: 'Settings'),
        ],
        selectedIndex: selectedIndex,
        onTabSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
      ),
      body: SafeArea(child: pages[selectedIndex]),
    );
  }
}

// ---------------------------------------------------------------------------
// HOME — grid of glass cards: LED (tap to toggle) + Distance
// ---------------------------------------------------------------------------

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      padding: const EdgeInsets.all(16),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 0.85,
      children: [
        const LedGridButton(),
        const FanGridButton(),
        AnimatedBuilder(

          animation: Listenable.merge(
              [AppState.instance.distanceCm, AppState.instance.metricSystem]),
          builder: (context, _) {
            final cm = AppState.instance.distanceCm.value;
            final metric = AppState.instance.metricSystem.value;
            String? display;
            if (cm != null) {
              final shown = metric ? cm : AppState.instance.cmToInches(cm);
              display = '${shown.toStringAsFixed(1)} ${metric ? 'cm' : 'in'}';
            }
            return SensorGridCard(
              icon: CupertinoIcons.arrow_up_down,
              label: metric ? 'Centimeters' : 'Inches',
              value: display,
            );
          },
        ),
      ],
    );
  }
}

/// The whole card is the button — tapping anywhere on it toggles the
/// ESP32's built-in LED using the same POST /api/status/ call as before.
/// Not tappable whenever the ESP32 is disconnected — same look, no
/// response on tap.
class LedGridButton extends StatelessWidget {
  const LedGridButton({super.key});


  @override
  Widget build(BuildContext context) {
    final accent = CupertinoTheme.of(context).primaryColor;
    final primary = primaryTextColor(context);
    final secondary = secondaryTextColor(context);
    return AnimatedBuilder(
      animation: Listenable.merge([AppState.instance.ledOn, AppState.instance.isConnected]),
      builder: (context, _) {
        final isOn = AppState.instance.ledOn.value;
        final connected = AppState.instance.isConnected.value;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: connected ? () => AppState.instance.setLed(!isOn) : null,
          child: GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isOn ? 'ON' : 'OFF',
                      style: TextStyle(
                        color: isOn ? accent : secondary,
                        fontSize: 13,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Icon(
                      CupertinoIcons.lightbulb_fill,
                      color: isOn ? accent : secondary,
                      size: 44,
                    ),
                    const SizedBox(height: 14),
                    Text('LED', style: TextStyle(color: primary, fontSize: 17)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
class FanGridButton extends StatelessWidget {
  const FanGridButton({super.key});

  @override
  Widget build(BuildContext context) {
    final accent = CupertinoTheme.of(context).primaryColor;
    final primary = primaryTextColor(context);
    final secondary = secondaryTextColor(context);

    return AnimatedBuilder(
      animation: Listenable.merge([
        AppState.instance.fanOn,
        AppState.instance.isConnected,
      ]),
      builder: (context, _) {
        final isOn = AppState.instance.fanOn.value;
        final connected = AppState.instance.isConnected.value;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: connected
              ? () => AppState.instance.setFan(!isOn)
              : null,
          child: GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isOn ? "ON" : "OFF",
                      style: TextStyle(
                        color: isOn ? accent : secondary,
                        fontSize: 13,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),

                    Icon(
                      CupertinoIcons.wind,
                      color: isOn ? accent : secondary,
                      size: 44,
                    ),

                    const SizedBox(height: 14),

                    Text(
                      "Clip Fan",
                      style: TextStyle(
                        color: primary,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
class SensorGridCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;

  const SensorGridCard({super.key, required this.icon, required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    final accent = CupertinoTheme.of(context).primaryColor;
    final primary = primaryTextColor(context);
    final display = value ?? '—  —  —';
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(display, style: TextStyle(color: primary, fontSize: 14, letterSpacing: 2)),
              const SizedBox(height: 14),
              Icon(icon, color: accent, size: 44),
              const SizedBox(height: 14),
              Text(label, style: TextStyle(color: primary, fontSize: 17)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SETTINGS — device/sensor status, dark mode, theme color, units.
// ---------------------------------------------------------------------------

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final secondary = secondaryTextColor(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        GlassGroupedSection(
          children: [
            _SettingsRow(
              iconBg: const Color(0xFF0A84FF),
              icon: CupertinoIcons.wifi,
              title: 'Device Status',
              trailing: ValueListenableBuilder<bool>(
                valueListenable: AppState.instance.isConnected,
                builder: (context, connected, _) => Text(
                  connected ? 'Connected' : 'Disconnected',
                  style: TextStyle(color: secondary),
                ),
              ),
            ),
            _SettingsRow(
              iconBg: const Color(0xFF34C759),
              icon: CupertinoIcons.antenna_radiowaves_left_right,
              title: 'Sensor Status',
              trailing: ValueListenableBuilder<bool>(
                valueListenable: AppState.instance.sensorOk,
                builder: (context, ok, _) => Text(
                  ok ? 'OK' : 'No Signal',
                  style: TextStyle(color: secondary),
                ),
              ),
            ),
            _SettingsRow(
              iconBg: const Color(0xFFAF52DE),
              icon: CupertinoIcons.moon_fill,
              title: 'Dark Mode',
              trailing: ValueListenableBuilder<bool>(
                valueListenable: AppState.instance.darkMode,
                builder: (context, isDark, _) => GlassSwitch(
                  value: isDark,
                  onChanged: (v) => AppState.instance.darkMode.value = v,
                ),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showColorPicker(context),
              child: ValueListenableBuilder<Color>(
                valueListenable: AppState.instance.themeColor,
                builder: (context, color, _) => _SettingsRow(
                  iconBg: const Color(0xFFFF375F),
                  icon: CupertinoIcons.paintbrush_fill,
                  title: 'Theme',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Icon(CupertinoIcons.chevron_forward, color: secondary, size: 18),
                    ],
                  ),
                ),
              ),
            ),
            _SettingsRow(
              iconBg: const Color(0xFFFF9F0A),
              icon: CupertinoIcons.arrow_2_squarepath,
              title: 'Units',
              trailing: ValueListenableBuilder<bool>(
                valueListenable: AppState.instance.metricSystem,
                builder: (context, metric, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(metric ? 'cm' : 'inches', style: TextStyle(color: secondary)),
                    const SizedBox(width: 8),
                    GlassSwitch(
                      value: metric,
                      onChanged: (v) => AppState.instance.metricSystem.value = v,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final Color iconBg;
  final IconData icon;
  final String title;
  final Widget trailing;

  const _SettingsRow({
    required this.iconBg,
    required this.icon,
    required this.title,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final primary = primaryTextColor(context);
    return GlassListTile(
      leading: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(7)),
        child: Icon(icon, color: CupertinoColors.white, size: 16),
      ),
      title: Text(title, style: TextStyle(color: primary, fontSize: 16)),
      trailing: trailing,
    );
  }
}

// Preset swatches — tapping one updates AppState.themeColor, which flows
// into CupertinoApp's primaryColor and repaints every accent-colored
// icon/label/tab automatically.
void _showColorPicker(BuildContext context) {
  final options = <Color>[
    const Color(0xFF32D74B), // green (default)
    const Color(0xFF0A84FF), // blue
    const Color(0xFFAF52DE), // purple
    const Color(0xFFFF375F), // pink
    const Color(0xFFFF9F0A), // orange
    const Color(0xFF64D2FF), // teal
    const Color(0xFFFFD60A), // yellow
  ];

  showCupertinoModalPopup(
    context: context,
    builder: (context) {
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Choose Theme Color',
                  style: TextStyle(
                      color: CupertinoColors.white, fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              ValueListenableBuilder<Color>(
                valueListenable: AppState.instance.themeColor,
                builder: (context, selected, _) {
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: options.map((color) {
                      final isSelected = selected == color;
                      return GestureDetector(
                        onTap: () {
                          AppState.instance.themeColor.value = color;
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: CupertinoColors.white, width: 3)
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

