//Imports for syncing with google spreadsheets
//TODO: make accounts and accoount types(admin, runners for a team, team organizer/coach)
//TODO: add in a map feature and all that comes out of it - sister runs, starting places, add ons, etc.
// ignore: todo
//TODO: get someone(mimi maybe?) to make better art and pictures and an app icon
//TODO: place for coach to assign runs

// ignore_for_file: empty_catches

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'dart:core';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert' show json;
import 'package:http/http.dart' as http;
import 'keyboardoverlay.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:collection';
import 'package:geolocator/geolocator.dart';

//Variables to be changed in settings
String _defaultStart = startingPlaces.keys.toList()[0];
double desiredMargin = .25;
double maxMargin = .5;
bool justDown = false;
String runStartInput = _defaultStart;
bool timePace = false;
bool darkMode = false;
int minRuns = 3;

//random variables I want to be global
//oB = out (and) Back
// ignore: prefer_typing_uninitialized_variables
late final prefs;
String oB = "Both";
String type = "Normal Run";
bool warmUp = false;
List<String> oBValues = ["Loops", "Both", "Out and Back Only"];
List<String> runTypeValues = ["Normal Run", "Warmup Only", "Hillsprint Only"];
String downText = (justDown)
    ? 'Look for shorter and longer runs'
    : 'Only look for shorter runs';
List<Run> choosen = [];
List<Run> allRunsList = [];
List<String> favorites = [];
List<String> hateds = ["898413", "898402", "898401"];
Map<String, List<String>> startingPlaces = {
  "Grandview": ["39.5895", "-104.7472"]
};
final kToday = DateTime.now();
final kFirstDay = DateTime(kToday.year, kToday.month - 3, kToday.day);
final kLastDay = DateTime(kToday.year, kToday.month + 3, kToday.day);
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  desiredMargin = prefs.getDouble('desiredMargin') ?? .25;
  _defaultStart =
      prefs.getString('_defaultStart') ?? startingPlaces.keys.toList()[0];
  maxMargin = prefs.getDouble('maxMargin') ?? .5;
  justDown = prefs.getBool('justDown') ?? false;
  minRuns = prefs.getInt('minRuns') ?? 3;
  favorites = prefs.getStringList('favorites') ?? [];
  hateds = prefs.getStringList('hateds') ?? ["898413", "898402", "898401"];

  allRunsList = await fetchRun();

  startingPlaces = getStartingPlaces();

  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: (MyApp()),
  ));
  runStartInput = _defaultStart;
}

Map<String, List<String>> getStartingPlaces() {
  Map<String, List<String>> places = {};
  for (Run run in allRunsList) {
    if (!places.keys.toList().contains(run.start.keys.toString())) {
      places.addAll(run.start);
    }
  }
  return places;
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Run Finder',
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.blueGrey,
      ),
      home: const MyHomePage(title: 'RunFinder'),
    );
  }
}

//Home page of finding a run
class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State oBject (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  //Create Controller for text field and dispose function to free up memory:
  final myController = TextEditingController();
  final timeController = TextEditingController();
  final paceController = TextEditingController();
  final FocusNode focusNode1 = FocusNode();
  final FocusNode focusNode2 = FocusNode();

  List<String> surfaceList = ['Sidewalk', 'Road', 'Dirt'];
  List<String> selectedSurfaces = [];
  List<String> steepnessList = ['Flat', 'Medium', 'Steep', 'Everest'];
  List<String> selectedSteepness = [];
  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    myController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    focusNode1.addListener(() {
      bool hasFocus = focusNode1.hasFocus;
      if (hasFocus) {
        KeyboardOverlay.showOverlay(context);
      } else {
        KeyboardOverlay.removeOverlay();
      }
    });
    focusNode2.addListener(() {
      bool hasFocus = focusNode2.hasFocus;
      if (hasFocus) {
        KeyboardOverlay.showOverlay(context);
      } else {
        KeyboardOverlay.removeOverlay();
      }
    });
  }

  void _findRun() {
    //empty the list to not keep old possibilites
    choosen = [];
    double distance;
    //find and add any runs that match the given parameters

    try {
      if (timePace) {
        String lengthStr = timeController.text;
        String paceStr = paceController.text;

        //find the length of the runs in hours
        double length = int.parse(lengthStr.substring(0, 2)).toDouble() +
            int.parse(lengthStr.substring(3, 5)) / 60.0 +
            int.parse(lengthStr.substring(6, 8)) / 3600.0;
        //find the pace in mph
        double pace = 60.0 / int.parse(paceStr.substring(3, 5)) +
            int.parse(paceStr.substring(6, 8));
        distance = length * pace;
      } else {
        distance = double.parse(myController.text);
      }
      double margin = 0;
      //If they selected Loops only
      if (oB == "Loops") {
        while (margin <= desiredMargin + .01 ||
            (margin <= maxMargin + .01 && choosen.length < minRuns)) {
          for (Run run in allRunsList) {
            //Make sure you start in the right place and its not an out and back
            if (run.start.keys.toString() == ("(" + runStartInput + ")") &&
                run.loop) {
              //If they selected Normal Run
              if (type == "Normal Run" && !run.hill) {
                //See if they selected shorter runs only
                if (justDown) {
                  //see if it is within the margin of error
                  if (run.distance >= (distance - margin) &&
                      run.distance <= (distance + margin)) {
                    //make sure there wont be any repeats
                    if (!choosen.contains(run)) {
                      choosen.add(run);
                    }
                  }
                } else {
                  if (run.distance >= (distance - margin) &&
                      run.distance <= (distance)) {
                    //make sure there wont be any repeats
                    if (!choosen.contains(run)) {
                      choosen.add(run);
                    }
                  }
                }
                //If they selected Warmup
              } else if (type == "Warmup Only" && run.warmUp) {
                //See if they selected shorter runs only
                if (justDown) {
                  //see if it is within the margin of error
                  if (run.distance >= (distance - margin) &&
                      run.distance <= (distance + margin)) {
                    //make sure there wont be any repeats
                    if (!choosen.contains(run)) {
                      choosen.add(run);
                    }
                  }
                } else {
                  if (run.distance >= (distance - margin) &&
                      run.distance <= (distance)) {
                    //make sure there wont be any repeats
                    if (!choosen.contains(run)) {
                      choosen.add(run);
                    }
                  }
                }
              }
            }
          }
          margin += .01;
        }
      } //Both out and backs and loops
      else if (oB == "Both") {
        while (margin <= desiredMargin + .01 ||
            (margin <= maxMargin + .01 && choosen.length < minRuns)) {
          for (Run run in allRunsList) {
            //Make sure you start in the right place
            if (run.start.keys.toString() == ("(" + runStartInput + ")")) {
              //If they selected Normal Run
              if (type == "Normal Run" && !run.hill) {
                //If its a loop
                if (run.loop) {
                  //See if they selected shorter runs only
                  if (justDown) {
                    //see if it is within the margin of error
                    if (run.distance >= (distance - margin) &&
                        run.distance <= (distance + margin)) {
                      //make sure there wont be any repeats
                      if (!choosen.contains(run)) {
                        choosen.add(run);
                      }
                    }
                  } else {
                    if (run.distance >= (distance - margin) &&
                        run.distance <= (distance)) {
                      //make sure there wont be any repeats
                      if (!choosen.contains(run)) {
                        choosen.add(run);
                      }
                    }
                  }
                  //If its an out and back
                } else {
                  //See if the run fits
                  if (distance / 2.0 <= run.distance) {
                    //make sure there wont be any repeats
                    if (!choosen.contains(run)) {
                      choosen.add(run);
                    }
                  }
                }
                //If they selected Warmup
              } else if (type == "Warmup Only" && run.warmUp) {
                //If its a loop
                if (run.loop) {
                  //See if they selected shorter runs only
                  if (justDown) {
                    //see if it is within the margin of error
                    if (run.distance >= (distance - margin) &&
                        run.distance <= (distance + margin)) {
                      //make sure there wont be any repeats
                      if (!choosen.contains(run)) {
                        choosen.add(run);
                      }
                    }
                  } else {
                    if (run.distance >= (distance - margin) &&
                        run.distance <= (distance)) {
                      //make sure there wont be any repeats
                      if (!choosen.contains(run)) {
                        choosen.add(run);
                      }
                    }
                  }
                } //If its an out and back
                else {
                  //See if the run fits
                  if (distance / 2.0 <= run.distance) {
                    //make sure there wont be any repeats
                    if (!choosen.contains(run)) {
                      choosen.add(run);
                    }
                  }
                }
                //If they selected Hill sprint only
              } else if (type == "Hillsprint Only" && run.hill) {
                //If its a loop
                if (run.loop) {
                  //See if they selected shorter runs only
                  if (justDown) {
                    //see if it is within the margin of error
                    if (run.distance >= (distance - margin) &&
                        run.distance <= (distance + margin)) {
                      //make sure there wont be any repeats
                      if (!choosen.contains(run)) {
                        choosen.add(run);
                      }
                    }
                  } else {
                    if (run.distance >= (distance - margin) &&
                        run.distance <= (distance)) {
                      //make sure there wont be any repeats
                      if (!choosen.contains(run)) {
                        choosen.add(run);
                      }
                    }
                  }
                  //If its an out and back
                } else {
                  //See if the run fits
                  if (distance / 2.0 <= run.distance) {
                    //make sure there wont be any repeats
                    if (!choosen.contains(run)) {
                      choosen.add(run);
                    }
                  }
                }
              }
            }
          }
          margin += .01;
        }
      } //Just out and backs
      else {
        for (Run run in allRunsList) {
          //Make sure you start in the right place
          if (run.start.keys.toString() == ("(" + runStartInput + ")") &&
              !run.loop) {
            //If they selected Normal Run
            if (type == "Normal Run" && !run.hill) {
              //See if the run fits
              if (distance / 2.0 <= run.distance) {
                //make sure there wont be any repeats
                if (!choosen.contains(run)) {
                  choosen.add(run);
                }
              }
              //If they selected Warmup
            } else if (type == "Warmup Only" && run.warmUp) {
              //See if the run fits
              if (distance / 2.0 <= run.distance) {
                //make sure there wont be any repeats
                if (!choosen.contains(run)) {
                  choosen.add(run);
                }
              }
              //If they selected Hill sprint only
            } else if (type == "Hillsprint Only" && run.hill) {
              //See if the run fits
              if (distance / 2.0 <= run.distance) {
                //make sure there wont be any repeats
                if (!choosen.contains(run)) {
                  choosen.add(run);
                }
              }
            }
          }
        }
      }
      choosen.sort();
      //Go to second Screen:
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreenSecondScreen()),
      );
    } on Exception {
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text("Invalid Input"),
              content: const Text("Check your inputs."),
              actions: [
                TextButton(
                  child: const Text("OK"),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return GestureDetector(
      onTap: () {
        final FocusScopeNode currentScope = FocusScope.of(context);
        if (!currentScope.hasPrimaryFocus && currentScope.hasFocus) {
          FocusManager.instance.primaryFocus!.unfocus();
        }
      },
      child: Scaffold(
        //stop background image from resizing when keyboard is present
        resizeToAvoidBottomInset: false,
        drawer: const NavDrawer(),
        appBar: AppBar(
          // Here we take the value from the MyHomePage oBject that was created by
          // the App.build method, and use it to set our appbar title.
          title: Text(widget.title),
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            image: DecorationImage(
                fit: BoxFit.fitHeight,
                invertColors: false,
                colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.1), BlendMode.dstATop),
                image: const AssetImage('assets/Map.jpeg')),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                height: MediaQuery.of(context).size.height / 5.7,
              ),
              //Text(sheet?.values.row(1)),
              const Text(
                'Select where you are running from:',
              ),
              //Find Run.start:
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  //Get current location and automatically choose a starting place
                  IconButton(
                      onPressed: () async {
                        String update = "";
                        Position pos = await _determinePosition();
                        for (String start in startingPlaces.keys) {
                          if (Geolocator.distanceBetween(
                                  double.parse(startingPlaces[start]![0]),
                                  double.parse(startingPlaces[start]![1]),
                                  pos.latitude,
                                  pos.longitude) <=
                              1000) {
                            update = start;
                          }
                        }
                        setState(() {
                          runStartInput = update;
                        });
                      },
                      icon: const Icon(Icons.my_location)),
                  //manually select starting place
                  DropdownButton(
                    value: runStartInput,
                    icon: const Icon(Icons.expand_more),
                    elevation: 16,
                    underline: Container(
                      height: 2,
                    ),
                    onChanged: (String? newValue) {
                      setState(() {
                        runStartInput = newValue!;
                      });
                    },
                    items: startingPlaces.keys
                        .toList()
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ],
              ),

              //Padding
              const SizedBox(height: 10),

              //Input Desired Mileage or time and pace:
              (timePace)
                  //Time pace
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        //Time:
                        SizedBox(
                          width: 150,
                          child: TextFormField(
                            controller: timeController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: false),
                            decoration: const InputDecoration(
                              hintText: '00:00:00',
                              labelText: "Time: ",
                            ),
                            inputFormatters: <TextInputFormatter>[
                              TimeTextInputFormatter() // This input formatter will do the job
                            ],
                          ),
                        ),
                        //Pace:
                        SizedBox(
                          width: 150,
                          child: TextFormField(
                            controller: paceController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: false),
                            decoration: const InputDecoration(
                              hintText: '00:00:00',
                              labelText: "Pace: ",
                            ),
                            inputFormatters: <TextInputFormatter>[
                              TimeTextInputFormatter() // This input formatter will do the job
                            ],
                          ),
                        ),
                      ],
                    )
                  : //Distance mode
                  SizedBox(
                      width: 300,
                      child: TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Goal Distance:',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        controller: myController,
                        onSubmitted: (value) {
                          _findRun();
                        },
                        
                      ),
                    ),

              //Padding
              const SizedBox(height: 20),

              SizedBox(
                width: 374,
                child: ExpansionTile(
                  title: SizedBox(
                    width: 300,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        //Toggle out and back(oB), loops, and both
                        DropdownButton(
                          items: oBValues
                              .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          icon: const Icon(Icons.expand_more_rounded),
                          value: oB,
                          onChanged: (String? value) {
                            setState(() {
                              oB = value!;
                              if (oB != "Out and Back Only" &&
                                  type == "Hillsprint Only") {
                                type = "Normal Run";
                              }
                            });
                          },
                        ),
                        const SizedBox(
                          width: 6,
                        ),
                        //Toggle hill sprint, warmup, and Normal Run
                        DropdownButton(
                          items: runTypeValues
                              .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          icon: const Icon(Icons.expand_more_rounded),
                          value: type,
                          onChanged: (String? value) {
                            setState(() {
                              type = value!;
                              if (type == "Hillsprint Only") {
                                oB = "Out and Back Only";
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  children: [
                    SizedBox(
                      width: 315,
                      child: Row(
                        children: <Widget>[
                          //Select surface
                          MultiSelectDialogField(
                            items: surfaceList
                                .map((e) => MultiSelectItem(e, e))
                                .toList(),
                            listType: MultiSelectListType.CHIP,
                            title: const Text('Surface Type'),
                            buttonIcon: const Icon(Icons.terrain),
                            onConfirm: (results) {
                              //TODO: Implement functionality of surfaces
                            },
                            buttonText: const Text('Surface Type'),
                          ),
                          const SizedBox(width: 25),
                          //Select Steepness
                          MultiSelectDialogField(
                            items: steepnessList
                                .map((e) => MultiSelectItem(e, e))
                                .toList(),
                            listType: MultiSelectListType.CHIP,
                            title: const Text('Steepness'),
                            buttonIcon: const Icon(Icons.show_chart),
                            onConfirm: (results) {
                              //TODO: Implement functionality of steepness
                            },
                            buttonText: const Text('Steepness'),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),

              //Find run button
              FloatingActionButton(
                onPressed: _findRun,
                tooltip: 'Find Run',
                child: const Icon(Icons.search),
                heroTag: 'findRunBtn',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//Second Screen:
class HomeScreenSecondScreen extends StatefulWidget {
  const HomeScreenSecondScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreenSecondScreen> createState() => _HomeScreenSecondScreenState();
}

class _HomeScreenSecondScreenState extends State<HomeScreenSecondScreen> {
  @override
  /*
  void initState() {
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory();
    final IFrameElement _iframeElement = IFrameElement();

    _iframeElement.height = '500';
    _iframeElement.width = '500';
    _iframeElement.src = 'https://www.youtube.com/embed/RQzhAQlg2JQ';
    _iframeElement.style.border = 'none';
// ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      'iframeElement',
      (int viewId) => _iframeElement,
    );
    Widget _iframeWidget;
    _iframeWidget = HtmlElementView(
      key: UniqueKey(),
      viewType: 'iframeElement',
    );

    

    super.initState();
  }*/

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Run Options"),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
              fit: BoxFit.fitHeight,
              colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.1), BlendMode.dstATop),
              image: const AssetImage('assets/Map.jpeg')),
        ),
        child: ListView.builder(
            itemCount: choosen.length,
            itemBuilder: (context, index) {
              return Card(
                elevation: 5,
                child: Stack(
                  children: <Widget>[
                    Container(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: MediaQuery.of(context).size.width * (.8),
                              child: Text(
                                choosen[index].runName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 25),
                              ),
                            ),
                            Text(choosen[index].toString(includeName: false)),
                            RichText(
                                text: TextSpan(children: [
                              TextSpan(
                                text: "Route #" +
                                    choosen[index].route.toString() +
                                    " ",
                              ),
                              TextSpan(
                                  style: const TextStyle(
                                    //Gets to stay bc its link text
                                    color: Colors.blue,
                                    decoration: TextDecoration.underline,
                                  ),
                                  text: "Click here for more details.",
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () async {
                                      var url =
                                          "https://www.mappedometer.com/?maproute=" +
                                              choosen[index].route.toString();
                                      if (await canLaunch(url)) {
                                        await launch(url);
                                      } else {
                                        throw 'Could not launch $url';
                                      }
                                    }),
                            ])),
                          ],
                        )),
                    Positioned(
                        child: IconButton(
                          icon: (choosen[index].favorite)
                              ? const Icon(Icons.favorite_rounded,
                                  color: Colors.pink)
                              : const Icon(
                                  Icons.favorite_border_rounded,
                                  color: Colors.grey,
                                ),
                          onPressed: () async {
                            choosen[index].favorite = !choosen[index].favorite;
                            choosen[index].hated = false;
                            final prefs = await SharedPreferences.getInstance();
                            if (choosen[index].favorite) {
                              hateds.remove(choosen[index].route.toString());
                              favorites.add(choosen[index].route.toString());
                            } else {
                              favorites.remove(choosen[index].route.toString());
                            }
                            await prefs.setStringList('favorites', favorites);
                            await prefs.setStringList('hateds', hateds);
                            _syncFavsandHats();
                            setState(() {});
                          },
                          tooltip: "Favorite",
                        ),
                        right: 1.0),
                    Positioned(
                      child: IconButton(
                        icon: (choosen[index].hated)
                            ? Icon(Icons.sports_kabaddi, color: Colors.red[900])
                            : const Icon(Icons.sports_kabaddi_outlined,
                                color: Colors.grey),
                        onPressed: () async {
                          choosen[index].hated = !choosen[index].hated;
                          choosen[index].favorite = false;
                          final prefs = await SharedPreferences.getInstance();
                          if (choosen[index].hated) {
                            favorites.remove(choosen[index].route.toString());
                            hateds.add(choosen[index].route.toString());
                          } else {
                            hateds.remove(choosen[index].route.toString());
                          }
                          await prefs.setStringList('favorites', favorites);
                          await prefs.setStringList('hateds', hateds);
                          _syncFavsandHats();
                          setState(() {});
                        },
                        tooltip: "Hate",
                      ),
                      right: 30,
                    )
                  ],
                ),
              );
            }),
      ),
    );
  }
}

//Settings Screen:
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final maxController = TextEditingController();
  FocusNode focusNode1 = FocusNode();
  FocusNode focusNode2 = FocusNode();
  FocusNode focusNode3 = FocusNode();
  final desiredController = TextEditingController();
  final runsController = TextEditingController();
  // ignore: unused_element
  void _saveSettings() {
    setState(() {
      if (maxController.text != "") {
        maxMargin = double.parse(maxController.text);
      }
      if (desiredController.text != "") {
        desiredMargin = double.parse(desiredController.text);
      }
      _defaultStart = runStartInput;
    });
  }

  /* void _openRuns() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => RunScreen(
                  runs: fetchRun(),
                )));
  } */

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    desiredController.dispose();
    maxController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    focusNode1.addListener(() {
      bool hasFocus = focusNode1.hasFocus;
      if (hasFocus) {
        KeyboardOverlay.showOverlay(context);
      } else {
        KeyboardOverlay.removeOverlay();
      }
    });
    focusNode2.addListener(() {
      bool hasFocus = focusNode2.hasFocus;
      if (hasFocus) {
        KeyboardOverlay.showOverlay(context);
      } else {
        KeyboardOverlay.removeOverlay();
      }
    });
    focusNode3.addListener(() {
      bool hasFocus = focusNode3.hasFocus;
      if (hasFocus) {
        KeyboardOverlay.showOverlay(context);
      } else {
        KeyboardOverlay.removeOverlay();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      drawer: const NavDrawer(),
      body: Row(
        //Padding:
        children: <Widget>[
          const SizedBox(
            width: 20,
          ),
          //some code to make it not throw errors(give it dimensions)
          Expanded(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * .9,
              //Actual list View displaying different settings
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  //Choose default starting location
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      const Text('Default Starting Location'),
                      DropdownButton(
                        value: _defaultStart,
                        icon: const Icon(Icons.expand_more),
                        elevation: 16,
                        underline: Container(
                          height: 2,
                        ),
                        onChanged: (String? newValue) async {
                          final prefs = await SharedPreferences.getInstance();
                          setState(() {
                            WidgetsFlutterBinding.ensureInitialized();
                            runStartInput = newValue!;
                            _defaultStart = newValue;
                            prefs.setString('_defaultStart', newValue);
                          });
                        },
                        items: startingPlaces.keys
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  Text(
                    'Current: ' + _defaultStart.toString(),
                    style: TextStyle(
                        color: (MediaQuery.of(context).platformBrightness ==
                                Brightness.dark)
                            ? Colors.grey[400]
                            : Colors.grey[700]),
                  ),
                  //Choose Desired Margin of Error
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      const Text('Desired Margin of Error'),
                      SizedBox(
                        width: 105,
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: '.25',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          controller: desiredController,
                          textInputAction: TextInputAction.done,
                          focusNode: focusNode1,
                          onChanged: (value) async {
                            final prefs = await SharedPreferences.getInstance();
                            setState(() {
                              try {
                                desiredMargin = double.parse(value);
                                prefs.setDouble('desiredMargin', desiredMargin);
                              } on Exception {}
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Current: ' + desiredMargin.toString(),
                    style: TextStyle(
                        color: (MediaQuery.of(context).platformBrightness ==
                                Brightness.dark)
                            ? Colors.grey[400]
                            : Colors.grey[700]),
                  ),
                  //Choose Maximum Margin of Error
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      const Text('Maximum Margin of Error'),
                      SizedBox(
                        width: 105,
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: '.5',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          onChanged: (value) async {
                            final prefs = await SharedPreferences.getInstance();
                            setState(() {
                              try {
                                maxMargin = double.parse(value);
                                prefs.setDouble('maxMargin', maxMargin);
                              } on Exception {}
                            });
                          },
                          controller: maxController,
                          focusNode: focusNode2,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Current: ' + maxMargin.toString(),
                    style: TextStyle(
                        color: (MediaQuery.of(context).platformBrightness ==
                                Brightness.dark)
                            ? Colors.grey[400]
                            : Colors.grey[700]),
                  ),
                  //Choose Min runs
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      const Text('Minimum Number of Runs'),
                      SizedBox(
                        width: 105,
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: '3',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          onChanged: (value) async {
                            final prefs = await SharedPreferences.getInstance();
                            setState(() {
                              try {
                                minRuns = int.parse(value);
                                prefs.setInt('minRuns', minRuns);
                              } on Exception {}
                            });
                          },
                          controller: runsController,
                          focusNode: focusNode3,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Current: ' + minRuns.toString(),
                    style: TextStyle(
                        color: (MediaQuery.of(context).platformBrightness ==
                                Brightness.dark)
                            ? Colors.grey[400]
                            : Colors.grey[700]),
                  ),
                  //Choose whether to only look for shorter runs
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(downText),
                      Switch(
                        value: justDown,
                        onChanged: (value) async {
                          final prefs = await SharedPreferences.getInstance();
                          setState(() {
                            justDown = value;
                            prefs.setBool('justDown', justDown);
                            if (value) {
                              downText = 'Look for shorter and longer runs';
                            } else {
                              downText = 'Only look for shorter runs';
                            }
                          });
                        },
                      )
                    ],
                  ),
                  //Toggle Time/Pace method
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text((timePace)
                          ? "Choose based off of Time/Pace"
                          : "Choose based off of distance"),
                      IconButton(
                          onPressed: () {
                            setState(() {
                              timePace = !timePace;
                            });
                          },
                          icon: Icon((timePace)
                              ? Icons.timer_outlined
                              : Icons.timer_off_outlined))
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(
            width: 20,
          ),
        ],
      ),
      /* floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.table_chart),
        onPressed: _openRuns,
        tooltip: 'See Runs',
        heroTag: 'seeRunsBtn',
      ), */
    );
  }
}

//Screen to display all runs we have on record
class RunScreen extends StatefulWidget {
  final Future<List<Run>> runs;

  const RunScreen({Key? key, required this.runs}) : super(key: key);

  @override
  State<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen> {
  ScrollController myScrollController = ScrollController();

  void _syncRuns() async {
    allRunsList = await fetchRun();

    startingPlaces = getStartingPlaces();
    allRunsList.sort();
    _syncFavsandHats();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: (AppBar(
        title: Text('List of all ' + allRunsList.length.toString() + ' Runs'),
      )),
      drawer: const NavDrawer(),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
              fit: BoxFit.fitHeight,
              colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.1), BlendMode.dstATop),
              image: const AssetImage('assets/Map.jpeg')),
        ),
        child: Center(
            child: FutureBuilder<List<Run>>(
          future: widget.runs,
          builder: (context, snapshot) {
            // ignore: avoid_print
            if (snapshot.hasError) print(snapshot.error);
            return snapshot.hasData
                ? ListView.builder(
                    controller: myScrollController,
                    itemCount: allRunsList.length,
                    itemBuilder: (context, index) {
                      return Card(
                        elevation: 5,
                        child: Stack(
                          children: <Widget>[
                            Container(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: MediaQuery.of(context).size.width *
                                          (.8),
                                      child: Text(
                                        allRunsList[index].runName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 25),
                                      ),
                                    ),
                                    Text(allRunsList[index]
                                        .toString(includeName: false)),
                                    RichText(
                                        text: TextSpan(children: [
                                      TextSpan(
                                        text: "Route #" +
                                            allRunsList[index]
                                                .route
                                                .toString() +
                                            " ",
                                      ),
                                      TextSpan(
                                          style: const TextStyle(
                                            color: Colors.blue,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                          text: "Click here for more details.",
                                          recognizer: TapGestureRecognizer()
                                            ..onTap = () async {
                                              var url =
                                                  "https://www.mappedometer.com/?maproute=" +
                                                      snapshot
                                                          .data![index].route
                                                          .toString();
                                              if (await canLaunch(url)) {
                                                await launch(url);
                                              } else {
                                                throw 'Could not launch $url';
                                              }
                                            }),
                                    ])),
                                  ],
                                )),
                            Positioned(
                                child: IconButton(
                                  icon: (allRunsList[index].favorite)
                                      ? const Icon(Icons.favorite_rounded,
                                          color: Colors.redAccent)
                                      : const Icon(
                                          Icons.favorite_border_rounded,
                                          color: Colors.grey,
                                        ),
                                  onPressed: () async {
                                    allRunsList[index].favorite =
                                        !allRunsList[index].favorite;
                                    allRunsList[index].hated = false;
                                    final prefs =
                                        await SharedPreferences.getInstance();
                                    if (allRunsList[index].favorite) {
                                      hateds.remove(
                                          allRunsList[index].route.toString());
                                      favorites.add(
                                          allRunsList[index].route.toString());
                                    } else {
                                      favorites.remove(
                                          allRunsList[index].route.toString());
                                    }
                                    await prefs.setStringList(
                                        'favorites', favorites);
                                    await prefs.setStringList('hateds', hateds);
                                    _syncFavsandHats();
                                    setState(() {});
                                  },
                                  tooltip: "Favorite",
                                ),
                                right: 1.0),
                            Positioned(
                              child: IconButton(
                                icon: (allRunsList[index].hated)
                                    ? Icon(Icons.sports_kabaddi,
                                        color: Colors.red[900])
                                    : const Icon(Icons.sports_kabaddi_outlined,
                                        color: Colors.grey),
                                onPressed: () async {
                                  allRunsList[index].hated =
                                      !allRunsList[index].hated;
                                  allRunsList[index].favorite = false;
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  if (allRunsList[index].hated) {
                                    favorites.remove(
                                        allRunsList[index].route.toString());
                                    hateds.add(
                                        allRunsList[index].route.toString());
                                  } else {
                                    hateds.remove(
                                        allRunsList[index].route.toString());
                                  }
                                  await prefs.setStringList(
                                      'favorites', favorites);
                                  await prefs.setStringList('hateds', hateds);
                                  _syncFavsandHats();
                                  setState(() {});
                                },
                                tooltip: "Hate",
                              ),
                              right: 30,
                            )
                          ],
                        ),
                      );
                    })
                : const Center(
                    child: CircularProgressIndicator(),
                  );
          },
        )),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.sync),
        onPressed: () => {_syncRuns()},
        tooltip: 'Sync Runs',
        heroTag: 'syncRunsBtn',
      ),
    );
  }
}

//Find a long run location
class FindLongRunScreen extends StatefulWidget {
  const FindLongRunScreen({Key? key}) : super(key: key);

  @override
  _FindLongRunScreenState createState() => _FindLongRunScreenState();
}

class _FindLongRunScreenState extends State<FindLongRunScreen> {
  //Create Controller for text field and dispose function to free up memory:
  final myController = TextEditingController();
  final timeController = TextEditingController();
  final paceController = TextEditingController();
  final FocusNode focusNode1 = FocusNode();
  final FocusNode focusNode2 = FocusNode();
  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    myController.dispose();
    timeController.dispose();
    paceController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    focusNode1.addListener(() {
      bool hasFocus = focusNode1.hasFocus;
      if (hasFocus) {
        KeyboardOverlay.showOverlay(context);
      } else {
        KeyboardOverlay.removeOverlay();
      }
    });
    focusNode2.addListener(() {
      bool hasFocus = focusNode2.hasFocus;
      if (hasFocus) {
        KeyboardOverlay.showOverlay(context);
      } else {
        KeyboardOverlay.removeOverlay();
      }
    });
  }

  void _findLongRun() {
    //empty the list to not keep old possibilites
    choosen = [];
    double distance;
    //find and add any runs that match the given parameters

    try {
      if (timePace) {
        String lengthStr = timeController.text;
        String paceStr = paceController.text;

        //find the length of the runs in hours
        double length = int.parse(lengthStr.substring(0, 2)).toDouble() +
            int.parse(lengthStr.substring(3, 5)) / 60.0 +
            int.parse(lengthStr.substring(6, 8)) / 3600.0;
        //find the pace in mph
        double pace = 60.0 / int.parse(paceStr.substring(3, 5)) +
            int.parse(paceStr.substring(6, 8));
        distance = length * pace;
      } else {
        distance = double.parse(myController.text);
      }
      double margin = 0;
      //If they selected Loops only
      if (oB == "Loops") {
        while (margin <= desiredMargin + .01 ||
            (margin <= maxMargin + .01 && choosen.length < minRuns)) {
          for (Run run in allRunsList) {
            //Make sure you start in the right place and its not an out and back
            if (run.start.keys.toString() != _defaultStart && run.loop) {
              //See if they selected shorter runs only
              if (justDown) {
                //see if it is within the margin of error
                if (run.distance >= (distance - margin) &&
                    run.distance <= (distance + margin)) {
                  //make sure there wont be any repeats
                  if (!choosen.contains(run)) {
                    choosen.add(run);
                  }
                }
              } else {
                if (run.distance >= (distance - margin) &&
                    run.distance <= (distance)) {
                  //make sure there wont be any repeats
                  if (!choosen.contains(run)) {
                    choosen.add(run);
                  }
                }
              }
            }
          }
          margin += .01;
        }
        //Both out and backs and loops
      } else if (oB == "Both") {
        while (margin <= desiredMargin + .01 ||
            (margin <= maxMargin + .01 && choosen.length < minRuns)) {
          for (Run run in allRunsList) {
            //Make sure you start in the right place
            if (run.start.keys.toString() != _defaultStart) {
              //If its a loop
              if (run.loop) {
                //See if they selected shorter runs only
                if (justDown) {
                  //see if it is within the margin of error
                  if (run.distance >= (distance - margin) &&
                      run.distance <= (distance + margin)) {
                    //make sure there wont be any repeats
                    if (!choosen.contains(run)) {
                      choosen.add(run);
                    }
                  }
                } else {
                  if (run.distance >= (distance - margin) &&
                      run.distance <= (distance)) {
                    //make sure there wont be any repeats
                    if (!choosen.contains(run)) {
                      choosen.add(run);
                    }
                  }
                }
                //If its an out and back
              } else {
                //See if the run fits
                if (distance / 2.0 <= run.distance) {
                  //make sure there wont be any repeats
                  if (!choosen.contains(run)) {
                    choosen.add(run);
                  }
                }
              }
            }
          }
          margin += .01;
        }
        //Just out and backs
      } else {
        for (Run run in allRunsList) {
          //Make sure you start in the right place
          if (run.start.keys.toString() != _defaultStart && !run.loop) {
            //If they selected Normal Run
            if (type == "Normal Run" && !run.hill) {
              //See if the run fits
              if (distance / 2.0 <= run.distance) {
                //make sure there wont be any repeats
                if (!choosen.contains(run)) {
                  choosen.add(run);
                }
              }
            }
          }
        }
      }
      choosen.sort();
      //Go to second Screen:
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreenSecondScreen()),
      );
    } on Exception {
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text("Invalid Input"),
              content: const Text("Check your inputs."),
              actions: [
                TextButton(
                  child: const Text("OK"),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final FocusScopeNode currentScope = FocusScope.of(context);
        if (!currentScope.hasPrimaryFocus && currentScope.hasFocus) {
          FocusManager.instance.primaryFocus!.unfocus();
        }
      },
      child: Scaffold(
        //stop background image from resizing when keyboard is present
        resizeToAvoidBottomInset: false,
        drawer: const NavDrawer(),
        appBar: AppBar(
          title: const Text("Find a Location"),
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            image: DecorationImage(
                fit: BoxFit.fitHeight,
                colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.1), BlendMode.dstATop),
                image: const AssetImage('assets/Map.jpeg')),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  height: MediaQuery.of(context).size.height / 4,
                ),

                //Input Desired Mileage:
                (timePace)
                    //Time pace
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          //Time:
                          SizedBox(
                            width: 150,
                            child: TextFormField(
                              controller: timeController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: false),
                              decoration: const InputDecoration(
                                hintText: '00:00:00',
                                labelText: "Time: ",
                              ),
                              inputFormatters: <TextInputFormatter>[
                                TimeTextInputFormatter() // This input formatter will do the job
                              ],
                            ),
                          ),
                          //Pace:
                          SizedBox(
                            width: 150,
                            child: TextFormField(
                              controller: paceController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: false),
                              decoration: const InputDecoration(
                                hintText: '00:00:00',
                                labelText: "Pace: ",
                              ),
                              inputFormatters: <TextInputFormatter>[
                                TimeTextInputFormatter() // This input formatter will do the job
                              ],
                            ),
                          ),
                        ],
                      )
                    : //Distance mode
                    SizedBox(
                        width: 300,
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Goal Distance:',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          controller: myController,
                          onSubmitted: (value) {
                            _findLongRun();
                          },
                          focusNode: focusNode1,
                        ),
                      ),

                //Padding
                const SizedBox(height: 20),
                DropdownButton(
                  items: oBValues.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  icon: const Icon(Icons.expand_more_rounded),
                  value: oB,
                  onChanged: (String? value) {
                    setState(() {
                      oB = value!;
                    });
                  },
                ),

                //Find run button
                FloatingActionButton(
                  onPressed: _findLongRun,
                  tooltip: 'Find Run',
                  child: const Icon(Icons.search),
                  heroTag: 'findLongRunBtn',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CalendarPage extends StatefulWidget {
  const CalendarPage({Key? key}) : super(key: key);

  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late final ValueNotifier<List<Event>> _selectedEvents;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  RangeSelectionMode _rangeSelectionMode = RangeSelectionMode
      .toggledOff; // Can be toggled on/off by longpressing a date
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  @override
  void initState() {
    super.initState();

    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));
  }

  @override
  void dispose() {
    _selectedEvents.dispose();
    super.dispose();
  }

  List<Event> _getEventsForDay(DateTime day) {
    // Implementation example
    return kEvents[day] ?? [];
  }

  List<Event> _getEventsForRange(DateTime start, DateTime end) {
    // Implementation example
    final days = daysInRange(start, end);

    return [
      for (final d in days) ..._getEventsForDay(d),
    ];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        _rangeStart = null; // Important to clean those
        _rangeEnd = null;
        _rangeSelectionMode = RangeSelectionMode.toggledOff;
      });

      _selectedEvents.value = _getEventsForDay(selectedDay);
    }
  }

  void _onRangeSelected(DateTime? start, DateTime? end, DateTime focusedDay) {
    setState(() {
      _selectedDay = null;
      _focusedDay = focusedDay;
      _rangeStart = start;
      _rangeEnd = end;
      _rangeSelectionMode = RangeSelectionMode.toggledOn;
    });

    // `start` or `end` could be null
    if (start != null && end != null) {
      _selectedEvents.value = _getEventsForRange(start, end);
    } else if (start != null) {
      _selectedEvents.value = _getEventsForDay(start);
    } else if (end != null) {
      _selectedEvents.value = _getEventsForDay(end);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
      ),
      drawer: const NavDrawer(),
      body: Column(
        children: [
          TableCalendar<Event>(
            firstDay: kFirstDay,
            lastDay: kLastDay,
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            rangeStartDay: _rangeStart,
            rangeEndDay: _rangeEnd,
            calendarFormat: _calendarFormat,
            rangeSelectionMode: _rangeSelectionMode,
            eventLoader: _getEventsForDay,
            startingDayOfWeek: StartingDayOfWeek.monday,
            calendarStyle: const CalendarStyle(
              // Use `CalendarStyle` to customize the UI
              outsideDaysVisible: false,
            ),
            onDaySelected: _onDaySelected,
            onRangeSelected: _onRangeSelected,
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
          ),
          const SizedBox(height: 8.0),
          Expanded(
            child: ValueListenableBuilder<List<Event>>(
              valueListenable: _selectedEvents,
              builder: (context, value, _) {
                return ListView.builder(
                  itemCount: value.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 4.0,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: ListTile(
                        onTap: () => print('${value[index]}'),
                        title: Text('${value[index]}'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

//Run class and its declaration and variables and methods to get runs
class Run implements Comparable<Run> {
  Run({
    this.runName = 'Unnamed Run',
    required this.route,
    required this.distance,
    this.elevation = 'No Elevation Data Included',
    required this.start,
    required this.loop,
    this.hill = false,
    this.warmUp = false,
    this.favorite = false,
    this.hated = false,
    required this.steepness,
    required this.surfaces,
  });

  String runName;
  int route;
  double distance;
  String elevation;
  Map<String, List<String>> start;
  bool loop;
  bool hill;
  bool warmUp;
  bool favorite;
  bool hated;
  double steepness;
  List<String> surfaces;

  factory Run.fromMap(Map<String, dynamic> json) {
    List<String> surface = [];
    try {
      surface = json['surface'].split(', ');
    } on Exception {
      surface.add(json['surface']);
    }

    return Run(
      runName: json['name'],
      route: int.parse(json['route']),
      distance: double.parse(json['distance']),
      elevation: (json['elevation gain'] == "")
          ? 'No Elevation Data Included'
          : json['elevation gain'].toString(),
      start: {json['starting place']: json['(long, lat)'].split(',')},
      loop: json['loop'],
      hill: (json['hill repeats'] == "") ? false : true,
      warmUp: (json['warm up'] == "") ? false : true,
      steepness: (json['steepness'].toDouble()),
      hated: (json['hated'] == "")
          ? (hateds.contains(json['route']) ? true : false)
          : true,
      favorite: (json['favorite'] == "")
          ? (favorites.contains(json['route']) ? true : false)
          : true,
      surfaces: surface,
    );
  }

  @override
  String toString({bool includeName = true}) {
    String ret = "";
    if (includeName) {
      ret += runName + ": ";
    }
    if (warmUp) {
      ret += "Traditonally a warmup, a ";
    } else if (hill) {
      ret += "Tradtionally a hill sprint route, a ";
    } else {
      ret += "A ";
    }
    ret += distance.toString() +
        " mile " +
        ((loop) ? "loop" : "long out and back") +
        ", starting at " +
        start.keys.toString().substring(1, start.keys.toString().length - 1);
    ret += " on " + surfaces.join(', ');
    if (elevation != "") {
      ret += " and taking you up " +
          elevation.toString() +
          " feet (" +
          steepness.toStringAsFixed(2) +
          " ft/mi).";
    } else {
      ret += ".";
    }
    return ret;
    //TODO: get the map to display in the app if you select it
    //TODO: Make my own maps and check locations for starting places, add ons, sister runs, auto start location, options display on one map, etc.
  }

  @override
  int compareTo(Run other) {
    //if both are favorites
    if (favorite && other.favorite) {
      if (distance > other.distance) {
        return 1;
      } else if (distance < other.distance) {
        return -1;
      }
      //just this one is a favorite
    } else if (favorite) {
      return -1;
      //the other one is a favorite
    } else if (other.favorite) {
      return 1;
    } else {
      //neither is a favorite
      //if this one is hated
      if (hated) {
        return 1;
        //if the other one is hated
      } else if (other.hated) {
        return -1;
        //if neither are hated or favorited
      } else {
        if (distance > other.distance) {
          return 1;
        } else if (distance < other.distance) {
          return -1;
        } else {
          return 0;
        }
      }
    }
    return 0;
  }
}

List<Run> decodeRun(String responseBody) {
  final parsed = json.decode(responseBody).cast<Map<String, dynamic>>();
  return parsed.map<Run>((json) => Run.fromMap(json)).toList();
}

Future<List<Run>> fetchRun() async {
  final response = await http.get(Uri.parse(
      'https://script.google.com/macros/s/AKfycbxBvVbFgVMV5cOpj5ldtsT4sFeJY5lME7ofLoRoIqwiUkgZextFjICqKUE6kINm6wlQ/exec'));
  if (response.statusCode == 200) {
    return decodeRun(response.body);
  } else {
    throw Exception('Unable to fetch data from the REST API');
  }
}

void _syncFavsandHats() {
  for (Run run in allRunsList) {
    if (favorites.contains(run.route.toString())) {
      run.favorite = true;
      run.hated = false;
    } else if (hateds.contains(run.route.toString())) {
      run.hated = true;
      run.favorite = false;
    }
  }
  for (Run run in choosen) {
    if (favorites.contains(run.route.toString())) {
      run.favorite = true;
      run.hated = false;
    } else if (hateds.contains(run.route.toString())) {
      run.hated = true;
      run.favorite = false;
    }
  }
}

class NavDrawer extends StatelessWidget {
  const NavDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          const DrawerHeader(
            padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: Text(
              'Menu',
              style: TextStyle(fontSize: 25),
            ),
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                  'assets/Wolf.png',
                ),
                opacity: .15,
                fit: BoxFit.fitWidth,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () => {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const MyHomePage(
                          title: 'Run Finder',
                        )),
              )
            },
          ),
          ListTile(
            leading: const Icon(Icons.near_me),
            title: const Text('Find a Location'),
            onTap: () => {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const FindLongRunScreen()))
            },
          ),
          ListTile(
            leading: const Icon(Icons.list_alt),
            title: const Text('List of Runs'),
            onTap: () => {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => RunScreen(
                            runs: fetchRun(),
                          )))
            },
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Calendar'),
            onTap: () => {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CalendarPage()),
              )
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () => {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              )
            },
          ),
        ],
      ),
    );
  }
}

//Used to handle inputs of time for timepace mode
class TimeTextInputFormatter extends TextInputFormatter {
  late RegExp _exp;
  TimeTextInputFormatter() {
    _exp = RegExp(r'^[0-9:]+$');
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (_exp.hasMatch(newValue.text)) {
      TextSelection newSelection = newValue.selection;

      String value = newValue.text;
      String newText;

      String leftChunk = '';
      String rightChunk = '';

      if (value.length >= 8) {
        if (value.substring(0, 7) == '00:00:0') {
          leftChunk = '00:00:';
          rightChunk = value.substring(leftChunk.length + 1, value.length);
        } else if (value.substring(0, 6) == '00:00:') {
          leftChunk = '00:0';
          rightChunk = value.substring(6, 7) + ":" + value.substring(7);
        } else if (value.substring(0, 4) == '00:0') {
          leftChunk = '00:';
          rightChunk = value.substring(4, 5) +
              value.substring(6, 7) +
              ":" +
              value.substring(7);
        } else if (value.substring(0, 3) == '00:') {
          leftChunk = '0';
          rightChunk = value.substring(3, 4) +
              ":" +
              value.substring(4, 5) +
              value.substring(6, 7) +
              ":" +
              value.substring(7, 8) +
              value.substring(8);
        } else {
          leftChunk = '';
          rightChunk = value.substring(1, 2) +
              value.substring(3, 4) +
              ":" +
              value.substring(4, 5) +
              value.substring(6, 7) +
              ":" +
              value.substring(7);
        }
      } else if (value.length == 7) {
        if (value.substring(0, 7) == '00:00:0') {
          leftChunk = '';
          rightChunk = '';
        } else if (value.substring(0, 6) == '00:00:') {
          leftChunk = '00:00:0';
          rightChunk = value.substring(6, 7);
        } else if (value.substring(0, 1) == '0') {
          leftChunk = '00:';
          rightChunk = value.substring(1, 2) +
              value.substring(3, 4) +
              ":" +
              value.substring(4, 5) +
              value.substring(6, 7);
        } else {
          leftChunk = '';
          rightChunk = value.substring(1, 2) +
              value.substring(3, 4) +
              ":" +
              value.substring(4, 5) +
              value.substring(6, 7) +
              ":" +
              value.substring(7);
        }
      } else {
        leftChunk = '00:00:0';
        rightChunk = value;
      }

      if (oldValue.text.isNotEmpty && oldValue.text.substring(0, 1) != '0') {
        if (value.length > 7) {
          return oldValue;
        } else {
          leftChunk = '0';
          rightChunk = value.substring(0, 1) +
              ":" +
              value.substring(1, 2) +
              value.substring(3, 4) +
              ":" +
              value.substring(4, 5) +
              value.substring(6, 7);
        }
      }

      newText = leftChunk + rightChunk;

      newSelection = newValue.selection.copyWith(
        baseOffset: math.min(newText.length, newText.length),
        extentOffset: math.min(newText.length, newText.length),
      );

      return TextEditingValue(
        text: newText,
        selection: newSelection,
        composing: TextRange.empty,
      );
    }
    return oldValue;
  }
}

class Event {
  final String title;

  const Event(this.title);

  @override
  String toString() => title;
}

/// Example events.
///
/// Using a [LinkedHashMap] is highly recommended if you decide to use a map.
//TODO: add in runs or some better list? Import from prefs the last month and the future month
final kEvents = LinkedHashMap<DateTime, List<Event>>();
//TODO: Add in a way to add runs
//TODO: Possibly sync with garmin to have completed runs?

int getHashCode(DateTime key) {
  return key.day * 1000000 + key.month * 10000 + key.year;
}

/// Returns a list of [DateTime] objects from [first] to [last], inclusive.
List<DateTime> daysInRange(DateTime first, DateTime last) {
  final dayCount = last.difference(first).inDays + 1;
  return List.generate(
    dayCount,
    (index) => DateTime.utc(first.year, first.month, first.day + index),
  );
}

//Get Location Function
Future<Position> _determinePosition() async {
  bool serviceEnabled;
  LocationPermission permission;

  // Test if location services are enabled.
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    // Location services are not enabled don't continue
    // accessing the position and request users of the
    // App to enable the location services.
    return Future.error('Location services are disabled.');
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      // Permissions are denied, next time you could try
      // requesting permissions again (this is also where
      // Android's shouldShowRequestPermissionRationale
      // returned true. According to Android guidelines
      // your App should show an explanatory UI now.
      return Future.error('Location permissions are denied');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    // Permissions are denied forever, handle appropriately.
    return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.');
  }

  // When we reach here, permissions are granted and we can
  // continue accessing the position of the device.
  return await Geolocator.getCurrentPosition();
}
