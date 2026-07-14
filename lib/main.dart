import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize();

  runApp(
    LiquidGlassWidgets.wrap(
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(
        brightness: Brightness.dark,
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  //----------------------------------------
  // SWITCHES
  //----------------------------------------

  bool led = false;
  bool darkMode = true;
  bool metric = true;

  //----------------------------------------
  // SENSOR VALUES
  //----------------------------------------

  String airPollution = "---";
  String temperature = "--- °C";
  String distance = "--- cm";
  String pm1 = "---";
  String pm25 = "---";
  String pm10 = "---";

  //----------------------------------------
  // ESP32 LED
  //----------------------------------------

  Future<void> ledLight(bool state) async {
    String value = state ? "on" : "off";

    try {
      final response = await http.post(
        Uri.parse("http://192.168.4.1/api/status/"),
        body: {
          "state": value,
        },
      );

      debugPrint(response.body);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  //----------------------------------------
  // HOME PAGE
  //----------------------------------------

  Widget homePage() {
    return GlassScaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 18,
            mainAxisSpacing: 18,
            childAspectRatio: .95,
            children: [

              buildCard(
                CupertinoIcons.wind,
                "Air Pollution",
                airPollution,
              ),

              buildCard(
                CupertinoIcons.thermometer,
                "Celsius",
                temperature,
              ),

              buildCard(
                CupertinoIcons.arrow_left_right,
                "Distance",
                distance,
              ),

              buildCard(
                CupertinoIcons.cloud,
                "Ultrafine Particles",
                pm1,
              ),

              buildCard(
                CupertinoIcons.circle_grid_hex,
                "Fine Particles",
                pm25,
              ),

              buildCard(
                CupertinoIcons.burst,
                "Coarse Particles",
                pm10,
              ),
            ],
          ),
        ),
      ),
    );
  }

  //----------------------------------------
  // GLASS CARD
  //----------------------------------------

  Widget buildCard(
      IconData icon,
      String title,
      String value,
      ) {
    return GlassContainer(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [

          Text(
            value,
            style: const TextStyle(
              color: CupertinoColors.systemGrey,
              fontSize: 24,
            ),
          ),

          const SizedBox(height: 15),

          Icon(
            icon,
            color: CupertinoColors.systemGreen,
            size: 42,
          ),

          const SizedBox(height: 15),

          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  //----------------------------------------
  // SETTINGS PAGE
  //----------------------------------------

  Widget settingsPage() {
    return GlassScaffold(
      body: SafeArea(
        child: ListView(
          children: [

            CupertinoListSection.insetGrouped(
              backgroundColor: CupertinoColors.transparent,
              children: [

                GlassContainer(
                  child: GlassListTile(
                    leading: const Icon(
                      CupertinoIcons.wifi,
                      color: CupertinoColors.systemBlue,
                    ),
                    title: const Text("Device Status"),
                    trailing: const Text("Connected"),
                  ),
                ),

                GlassContainer(
                  child: GlassListTile(
                    leading: const Icon(
                      CupertinoIcons.moon_fill,
                      color: CupertinoColors.systemPurple,
                    ),
                    title: const Text("Dark Mode"),
                    trailing: GlassSwitch(
                      value: darkMode,
                      onChanged: (v) {
                        setState(() {
                          darkMode = v;
                        });
                      },
                    ),
                  ),
                ),

                GlassContainer(
                  child: GlassListTile(
                    leading: const Icon(
                      CupertinoIcons.paintbrush_fill,
                      color: CupertinoColors.systemPink,
                    ),
                    title: const Text("Theme"),
                    trailing: const Icon(
                      CupertinoIcons.chevron_forward,
                    ),
                  ),
                ),

                GlassContainer(
                  child: GlassListTile(
                    leading: const Icon(
                      CupertinoIcons.settings,
                      color: CupertinoColors.systemOrange,
                    ),
                    title: const Text("LED Control"),
                    trailing: GlassSwitch(
                      value: led,
                      onChanged: (v) {
                        setState(() {
                          led = v;
                        });

                        ledLight(v);
                      },
                    ),
                  ),
                ),

                GlassContainer(
                  child: GlassListTile(
                    leading: const Icon(
                      CupertinoIcons.speedometer,
                      color: CupertinoColors.systemGreen,
                    ),
                    title: const Text("System"),
                    trailing: GlassSwitch(
                      value: metric,
                      onChanged: (v) {
                        setState(() {
                          metric = v;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),

            CupertinoListSection.insetGrouped(
              backgroundColor: CupertinoColors.transparent,
              children: [

                GlassContainer(
                  child: GlassListTile(
                    title: const Text("Researchers and Developers"),
                    trailing: const Icon(
                      CupertinoIcons.chevron_forward,
                    ),
                  ),
                ),

                GlassContainer(
                  child: GlassListTile(
                    title: const Text("About Research"),
                    trailing: const Icon(
                      CupertinoIcons.chevron_forward,
                    ),
                  ),
                ),

                GlassContainer(
                  child: GlassListTile(
                    title: const Text("Version"),
                    trailing: const Text("1.1.2"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  //----------------------------------------
  // UI
  //----------------------------------------

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        activeColor: CupertinoColors.systemGreen,
        backgroundColor: CupertinoColors.black,
        items: [

          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.home),
            label: "Home",
          ),

          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.settings),
            label: "Settings",
          ),
        ],
      ),
      tabBuilder: (context, index) {
        if (index == 0) {
          return homePage();
        } else {
          return settingsPage();
        }
      },
    );
  }
}