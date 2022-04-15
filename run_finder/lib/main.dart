//TODO: make accoount types(admin, runners for a team, team organizer/coach)
//TODO: add in a map feature and all that comes out of it - sister runs, starting places, add ons, etc.
// ignore: todo
//TODO: get someone(mimi maybe?) to make better art and pictures and an app icon
//TODO: place for coach to assign runs
//ignore_for_file: empty_catches
//TODO: Comment everyhting, make it have proper practice
//TODO: make all global values into a seperate file
//TODO: make each page it's own file bc thats what youre supposed to do i think
import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'dart:core';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'keyboardoverlay.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:collection';
import 'package:geolocator/geolocator.dart';
import 'dart:io' show Platform;
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login.dart';
import 'team.dart';

//Global Variables
String _defaultStart = startingPlaces.keys.toList()[0];
double desiredMargin = .25;
double maxMargin = .5;
bool justDown = false;
String runStartInput = _defaultStart;
bool timePace = false;
bool darkMode = false;
int minRuns = 3;
String outAndBack = "Both";
String type = "Normal Run";
bool warmUp = false;
List<String> oBValues = ["Loops", "Both", "Out and Back Only"];
List<String> runTypeValues = ["Normal Run", "Warmup Only", "Hillsprint Only"];
String downText = (justDown) ? 'Look for shorter and longer runs' : 'Only look for shorter runs';
List<Run> choosen = [];
List<Run> allRunsList = [];
List<String> favorites = [];
List<String> hateds = ["898413", "898402", "898401"];
Map<String, List<String>> startingPlaces = {};
final kToday = DateTime.now();
final kFirstDay = DateTime(kToday.year, kToday.month - 3, kToday.day);
final kLastDay = DateTime(kToday.year, kToday.month + 3, kToday.day);
LinkedHashMap<DateTime, dynamic> kPlans = LinkedHashMap(equals: isSameDay, hashCode: getHashCode);
late Timer timer;
FirebaseFirestore firestore = FirebaseFirestore.instance;
bool coach = false;
String team = "None";
String group = "None";

void main() async {
  //Many thing have told me to do this, like firebase/cloud stuff
  WidgetsFlutterBinding.ensureInitialized();
  //Make sure the app isnt an empty white screen for like hours
  timer = Timer(const Duration(seconds: 15), () {
    timer.cancel();
    wontSync();
  });
  //Initilize firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  //Get preferences from profile(if logged in)
  if (FirebaseAuth.instance.currentUser != null) {
    syncFromProfile();
  }

  allRunsList = await fetchRun();
  startingPlaces = getStartingPlaces();
  _syncFavsandHats();
  allRunsList.sort();
  runStartInput = _defaultStart;
  if (timer.isActive) {
    runApp(const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: (MyApp()),
    ));
  }
  timer.cancel();
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
      debugShowCheckedModeBanner: false,
      title: 'Run Finder',
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Color.fromARGB(255, 24, 149, 233),

        //Floating action buttons use colorshceme.secondary
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

  List<String> selectedSurfaces = ['Road', 'Sidewalk', 'Dirt'];
  List<String> selectedSteepness = ['Flat', 'Medium', 'Steep', 'Everest'];
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
      if (hasFocus && !Platform.isMacOS) {
        KeyboardOverlay.showOverlay(context);
      } else {
        KeyboardOverlay.removeOverlay();
      }
    });
    focusNode2.addListener(() {
      bool hasFocus = focusNode2.hasFocus;
      if (hasFocus && !Platform.isMacOS) {
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
        double pace = 60.0 / int.parse(paceStr.substring(3, 5)) + int.parse(paceStr.substring(6, 8));
        distance = length * pace;
      } else {
        distance = double.parse(myController.text);
      }
      double margin = 0;
      //If they selected Loops only
      if (outAndBack == "Loops") {
        while (margin <= desiredMargin + .01 ||
            (margin <= maxMargin + .01 && choosen.length < minRuns)) {
          for (Run run in allRunsList) {
            bool goodSurface = true;
            bool goodSteepness = true;
            for (String surface in run.surfaces) {
              if (!selectedSurfaces.contains(surface)) {
                goodSurface = false;
              }
            }
            if (run.steepness < 45) {
              goodSteepness = selectedSteepness.contains('Flat');
            } else if (run.steepness < 75) {
              goodSteepness = selectedSteepness.contains('Medium');
            } else if (run.steepness < 125) {
              goodSteepness = selectedSteepness.contains('Steep');
            } else {
              goodSteepness = selectedSteepness.contains('Everest');
            }

            if (goodSteepness && goodSurface) {
              //Make sure you start in the right place and its not an out and back
              if (run.start.keys.toString() == ("(" + runStartInput + ")") && run.loop) {
                //If they selected Normal Run
                if (type == "Normal Run" && !run.hill) {
                  //See if they selected shorter runs only
                  if (justDown) {
                    //see if it is within the margin of error
                    if (run.distance >= (distance - margin) && run.distance <= (distance + margin)) {
                      //make sure there wont be any repeats
                      if (!choosen.contains(run)) {
                        choosen.add(run);
                      }
                    }
                  } else {
                    if (run.distance >= (distance - margin) && run.distance <= (distance)) {
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
                    if (run.distance >= (distance - margin) && run.distance <= (distance + margin)) {
                      //make sure there wont be any repeats
                      if (!choosen.contains(run)) {
                        choosen.add(run);
                      }
                    }
                  } else {
                    if (run.distance >= (distance - margin) && run.distance <= (distance)) {
                      //make sure there wont be any repeats
                      if (!choosen.contains(run)) {
                        choosen.add(run);
                      }
                    }
                  }
                }
              }
            }
          }
          margin += .01;
        }
      } //Both out and backs and loops
      else if (outAndBack == "Both") {
        while (margin <= desiredMargin + .01 ||
            (margin <= maxMargin + .01 && choosen.length < minRuns)) {
          for (Run run in allRunsList) {
            bool goodSurface = true;
            bool goodSteepness = true;
            for (String surface in run.surfaces) {
              if (!selectedSurfaces.contains(surface)) {
                goodSurface = false;
              }
            }
            if (run.steepness < 45) {
              goodSteepness = selectedSteepness.contains('Flat');
            } else if (run.steepness < 75) {
              goodSteepness = selectedSteepness.contains('Medium');
            } else if (run.steepness < 125) {
              goodSteepness = selectedSteepness.contains('Steep');
            } else {
              goodSteepness = selectedSteepness.contains('Everest');
            }

            if (goodSteepness && goodSurface) {
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
                      if (run.distance >= (distance - margin) && run.distance <= (distance)) {
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
                      if (run.distance >= (distance - margin) && run.distance <= (distance)) {
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
                      if (run.distance >= (distance - margin) && run.distance <= (distance)) {
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
          }
          margin += .01;
        }
      } //Just out and backs
      else {
        for (Run run in allRunsList) {
          bool goodSurface = true;
          bool goodSteepness = true;
          for (String surface in run.surfaces) {
            if (!selectedSurfaces.contains(surface)) {
              goodSurface = false;
            }
          }
          if (run.steepness < 45) {
            goodSteepness = selectedSteepness.contains('Flat');
          } else if (run.steepness < 75) {
            goodSteepness = selectedSteepness.contains('Medium');
          } else if (run.steepness < 125) {
            goodSteepness = selectedSteepness.contains('Steep');
          } else {
            goodSteepness = selectedSteepness.contains('Everest');
          }

          if (goodSteepness && goodSurface) {
            //Make sure you start in the right place
            if (run.start.keys.toString() == ("(" + runStartInput + ")") && !run.loop) {
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
      }
      if (choosen.isEmpty) {
        showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text("No runs:("),
                content: const Text("Check your inputs, maybe widen your search."),
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
      } else {
        choosen.sort();

        //Go to second Screen:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ChoosenRunScreen()),
        );
      }
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
                colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.1), BlendMode.dstATop),
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
                      tooltip: "Use Current Location",
                      onPressed: () async {
                        String update = runStartInput;
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
                    items: startingPlaces.keys.toList().map<DropdownMenuItem<String>>((String value) {
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
                            keyboardType: const TextInputType.numberWithOptions(decimal: false),
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
                            keyboardType: const TextInputType.numberWithOptions(decimal: false),
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
                  Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 300,
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Goal Distance:',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            controller: myController,
                            onSubmitted: (value) {
                              _findRun();
                            },
                            focusNode: focusNode1,
                          ),
                        ),
                        Visibility(
                            visible: (kPlans[kToday] != null && kPlans[kToday].length == 1),
                            child: IconButton(
                              tooltip: "Get Distance From Calendar",
                              icon: const Icon(Icons.lightbulb),
                              onPressed: () {
                                myController.text = kPlans[kToday][0].distance.toString();
                                setState(() {});
                              },
                            ))
                      ],
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
                        //Toggle out and back(outAndBack), loops, and both
                        DropdownButton(
                          items: oBValues.map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          icon: const Icon(Icons.expand_more_rounded),
                          value: outAndBack,
                          onChanged: (String? value) {
                            setState(() {
                              outAndBack = value!;
                              if (outAndBack != "Out and Back Only" && type == "Hillsprint Only") {
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
                          items: runTypeValues.map<DropdownMenuItem<String>>((String value) {
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
                                outAndBack = "Out and Back Only";
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
                      //Select surface
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          //Select Sidewalk
                          SizedBox(
                            width: 315 / 3,
                            child: TextButton(
                              onPressed: () {
                                if (selectedSurfaces.contains("Sidewalk")) {
                                  selectedSurfaces.remove("Sidewalk");
                                } else {
                                  selectedSurfaces.add("Sidewalk");
                                }
                                setState(() {});
                              },
                              child: (selectedSurfaces.contains("Sidewalk")
                                  ? Row(
                                      children: const [
                                        Icon(Icons.terrain),
                                        Text("Sidewalk"),
                                      ],
                                    )
                                  : Text(
                                      "Sidewalk",
                                      style:
                                          TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                                    )),
                            ),
                          ),
                          //Select Roads
                          SizedBox(
                            width: 315 / 3,
                            child: TextButton(
                              onPressed: () {
                                if (selectedSurfaces.contains("Road")) {
                                  selectedSurfaces.remove("Road");
                                } else {
                                  selectedSurfaces.add("Road");
                                }
                                setState(() {});
                              },
                              child: (selectedSurfaces.contains("Road")
                                  ? Row(
                                      children: const [
                                        Icon(Icons.terrain),
                                        Text("Road"),
                                      ],
                                    )
                                  : Text(
                                      "Road",
                                      style:
                                          TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                                    )),
                            ),
                          ),
                          //Select Dirt
                          SizedBox(
                            width: 315 / 3,
                            child: TextButton(
                              onPressed: () {
                                if (selectedSurfaces.contains("Dirt")) {
                                  selectedSurfaces.remove("Dirt");
                                } else {
                                  selectedSurfaces.add("Dirt");
                                }
                                setState(() {});
                              },
                              child: (selectedSurfaces.contains("Dirt")
                                  ? Row(
                                      children: const [
                                        Icon(Icons.terrain),
                                        Text("Dirt"),
                                      ],
                                    )
                                  : Text(
                                      "Dirt",
                                      style:
                                          TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                                    )),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 332,
                      //Select Steepness
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          //Select Flat
                          SizedBox(
                            //width: 315 / 4.3,
                            child: TextButton(
                              onPressed: () {
                                if (selectedSteepness.contains("Flat")) {
                                  selectedSteepness.remove("Flat");
                                } else {
                                  selectedSteepness.add("Flat");
                                }
                                setState(() {});
                              },
                              child: (selectedSteepness.contains("Flat")
                                  ? Row(
                                      children: const [
                                        Icon(Icons.north_east),
                                        Text("Flat"),
                                      ],
                                    )
                                  : Text(
                                      "Flat",
                                      style:
                                          TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                                    )),
                            ),
                          ),
                          //Select Medium
                          SizedBox(
                            //width: 315 / 3.9,
                            child: TextButton(
                              onPressed: () {
                                if (selectedSteepness.contains("Medium")) {
                                  selectedSteepness.remove("Medium");
                                } else {
                                  selectedSteepness.add("Medium");
                                }
                                setState(() {});
                              },
                              child: (selectedSteepness.contains("Medium")
                                  ? Row(
                                      children: const [
                                        Icon(Icons.north_east),
                                        Text("Medium"),
                                      ],
                                    )
                                  : Text(
                                      "Medium",
                                      style:
                                          TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                                    )),
                            ),
                          ),
                          //Select Steep
                          SizedBox(
                            //width: 315 / 3.9,
                            child: TextButton(
                              onPressed: () {
                                if (selectedSteepness.contains("Steep")) {
                                  selectedSteepness.remove("Steep");
                                } else {
                                  selectedSteepness.add("Steep");
                                }
                                setState(() {});
                              },
                              child: (selectedSteepness.contains("Steep")
                                  ? Row(
                                      children: const [
                                        Icon(Icons.north_east),
                                        Text("Steep"),
                                      ],
                                    )
                                  : Text(
                                      "Steep",
                                      style:
                                          TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                                    )),
                            ),
                          ),
                          //Select Everest
                          SizedBox(
                            //width: 315 / 3.9,
                            child: TextButton(
                              onPressed: () {
                                if (selectedSteepness.contains("Everest")) {
                                  selectedSteepness.remove("Everest");
                                } else {
                                  selectedSteepness.add("Everest");
                                  //type = "Hillsprint Only";
                                }
                                setState(() {});
                              },
                              child: (selectedSteepness.contains("Everest")
                                  ? Row(
                                      children: const [
                                        Icon(Icons.north_east),
                                        Text("Everest"),
                                      ],
                                    )
                                  : Text(
                                      "Everest",
                                      style:
                                          TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                                    )),
                            ),
                          ),
                        ],
                      ),
                    ),
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
class ChoosenRunScreen extends StatefulWidget {
  const ChoosenRunScreen({Key? key}) : super(key: key);

  @override
  State<ChoosenRunScreen> createState() => _ChoosenRunScreenState();
}

class _ChoosenRunScreenState extends State<ChoosenRunScreen> {
  /*@override
  
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
              colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.1), BlendMode.dstATop),
              image: const AssetImage('assets/Map.jpeg')),
        ),
        child: ListView.builder(
            itemCount: choosen.length,
            itemBuilder: (context, index) {
              return InkWell(
                onLongPress: () async {
                  var url =
                      "https://www.mappedometer.com/?maproute=" + choosen[index].route.toString();
                  if (await canLaunch(url)) {
                    await launch(url);
                  } else {
                    throw 'Could not launch $url';
                  }
                },
                child: Card(
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
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 25),
                                ),
                              ),
                              Text(choosen[index].toString(includeName: false)),
                            ],
                          )),
                      Positioned(
                          child: IconButton(
                            icon: (choosen[index].favorite)
                                ? const Icon(Icons.favorite_rounded, color: Colors.pink)
                                : const Icon(
                                    Icons.favorite_border_rounded,
                                    color: Colors.grey,
                                  ),
                            onPressed: () async {
                              choosen[index].favorite = !choosen[index].favorite;
                              choosen[index].hated = false;
                              if (choosen[index].favorite) {
                                hateds.remove(choosen[index].route.toString());
                                favorites.add(choosen[index].route.toString());
                              } else {
                                favorites.remove(choosen[index].route.toString());
                              }
                              syncToProfile();
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
                              : const Icon(Icons.sports_kabaddi_outlined, color: Colors.grey),
                          onPressed: () async {
                            choosen[index].hated = !choosen[index].hated;
                            choosen[index].favorite = false;
                            if (choosen[index].hated) {
                              favorites.remove(choosen[index].route.toString());
                              hateds.add(choosen[index].route.toString());
                            } else {
                              hateds.remove(choosen[index].route.toString());
                            }
                            syncToProfile();
                            _syncFavsandHats();
                            setState(() {});
                          },
                          tooltip: "Hate",
                        ),
                        right: 30,
                      )
                    ],
                  ),
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
      if (hasFocus && !Platform.isMacOS) {
        KeyboardOverlay.showOverlay(context);
      } else {
        KeyboardOverlay.removeOverlay();
      }
    });
    focusNode2.addListener(() {
      bool hasFocus = focusNode2.hasFocus;
      if (hasFocus && !Platform.isMacOS) {
        KeyboardOverlay.showOverlay(context);
      } else {
        KeyboardOverlay.removeOverlay();
      }
    });
    focusNode3.addListener(() {
      bool hasFocus = focusNode3.hasFocus;
      if (hasFocus && !Platform.isMacOS) {
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
                          setState(() {
                            WidgetsFlutterBinding.ensureInitialized();
                            runStartInput = newValue!;
                            _defaultStart = newValue;
                            syncToProfile();
                          });
                        },
                        items: startingPlaces.keys.map<DropdownMenuItem<String>>((String value) {
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
                        color: (MediaQuery.of(context).platformBrightness == Brightness.dark)
                            ? Colors.grey[400]
                            : Colors.grey[700]),
                  ),
                  //Choose Desired Margin of Error
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      const Text('Desired Accuracy'),
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
                            setState(() {
                              try {
                                desiredMargin = double.parse(value);
                                syncToProfile();
                              } on Exception {}
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Current: ' + desiredMargin.toString() + " miles",
                    style: TextStyle(
                        color: (MediaQuery.of(context).platformBrightness == Brightness.dark)
                            ? Colors.grey[400]
                            : Colors.grey[700]),
                  ),
                  //Choose Maximum Margin of Error
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      const Text('Maximum Inaccuracy'),
                      SizedBox(
                        width: 105,
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: '.5',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (value) {
                            setState(() {
                              try {
                                maxMargin = double.parse(value);
                                syncToProfile();
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
                    'Current: ' + maxMargin.toString() + ' miles',
                    style: TextStyle(
                        color: (MediaQuery.of(context).platformBrightness == Brightness.dark)
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
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (value) {
                            setState(() {
                              try {
                                minRuns = int.parse(value);
                                syncToProfile();
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
                    'Current: ' + minRuns.toString() + " runs",
                    style: TextStyle(
                        color: (MediaQuery.of(context).platformBrightness == Brightness.dark)
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
                        onChanged: (value) {
                          setState(() {
                            justDown = value;
                            syncToProfile();
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
                          icon: Icon((timePace) ? Icons.timer_outlined : Icons.timer_off_outlined))
                    ],
                  ),
                  TextButton(
                    child: const Text("Privacy Policy"),
                    onPressed: () async {
                      const url = 'https://afoxenrichment.weebly.com/privacy-policy.html';
                      if (await canLaunch(url)) {
                        await launch(url);
                      } else {
                        throw 'Could not launch $url';
                      }
                    },
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
  const RunScreen({
    Key? key,
  }) : super(key: key);

  @override
  State<RunScreen> createState() => _RunScreenState();
}

//TODO: Implement filter by distance, starting place, etc.
//Do this by creating a holder list, then they fucntion will use the .where() function to change the holder, without ever accsessing or chanigng the or the original list
//like here but also with the filter option?
// https://www.kindacode.com/article/how-to-create-a-filter-search-listview-in-flutter/
class _RunScreenState extends State<RunScreen> {
  ScrollController myScrollController = ScrollController();

  void _syncRuns() async {
    allRunsList = await fetchRun();

    startingPlaces = getStartingPlaces();
    _syncFavsandHats();
    allRunsList.sort();
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
              colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.1), BlendMode.dstATop),
              image: const AssetImage('assets/Map.jpeg')),
        ),
        child: Center(
            child: ListView.builder(
                controller: myScrollController,
                itemCount: allRunsList.length,
                itemBuilder: (context, index) {
                  return InkWell(
                    child: Card(
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
                                      allRunsList[index].runName,
                                      style:
                                          const TextStyle(fontWeight: FontWeight.bold, fontSize: 25),
                                    ),
                                  ),
                                  Text(allRunsList[index].toString(includeName: false)),
                                  RichText(
                                      text: TextSpan(children: [
                                    TextSpan(
                                      text: "Route #" + allRunsList[index].route.toString() + " ",
                                    ),
                                  ])),
                                ],
                              )),
                          Positioned(
                              child: IconButton(
                                icon: (allRunsList[index].favorite)
                                    ? const Icon(Icons.favorite_rounded, color: Colors.redAccent)
                                    : const Icon(
                                        Icons.favorite_border_rounded,
                                        color: Colors.grey,
                                      ),
                                onPressed: () {
                                  allRunsList[index].favorite = !allRunsList[index].favorite;
                                  allRunsList[index].hated = false;
                                  if (allRunsList[index].favorite) {
                                    hateds.remove(allRunsList[index].route.toString());
                                    favorites.add(allRunsList[index].route.toString());
                                  } else {
                                    favorites.remove(allRunsList[index].route.toString());
                                  }
                                  syncToProfile();
                                  _syncFavsandHats();
                                  allRunsList.sort();

                                  setState(() {});
                                },
                                tooltip: "Favorite",
                              ),
                              right: 1.0),
                          Positioned(
                            child: IconButton(
                              icon: (allRunsList[index].hated)
                                  ? Icon(Icons.sports_kabaddi, color: Colors.red[900])
                                  : const Icon(Icons.sports_kabaddi_outlined, color: Colors.grey),
                              onPressed: () {
                                allRunsList[index].hated = !allRunsList[index].hated;
                                allRunsList[index].favorite = false;
                                if (allRunsList[index].hated) {
                                  favorites.remove(allRunsList[index].route.toString());
                                  hateds.add(allRunsList[index].route.toString());
                                } else {
                                  hateds.remove(allRunsList[index].route.toString());
                                }
                                syncToProfile();
                                _syncFavsandHats();
                                allRunsList.sort();
                                setState(() {});
                              },
                              tooltip: "Hate",
                            ),
                            right: 30,
                          )
                        ],
                      ),
                    ),
                    onLongPress: () async {
                      var url = "https://www.mappedometer.com/?maproute=" +
                          allRunsList[index].route.toString();
                      if (await canLaunch(url)) {
                        await launch(url);
                      } else {
                        throw 'Could not launch $url';
                      }
                    },
                  );
                })),
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
      if (hasFocus && !Platform.isMacOS) {
        KeyboardOverlay.showOverlay(context);
      } else {
        KeyboardOverlay.removeOverlay();
      }
    });
    focusNode2.addListener(() {
      bool hasFocus = focusNode2.hasFocus;
      if (hasFocus && !Platform.isMacOS) {
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
        double pace = 60.0 / int.parse(paceStr.substring(3, 5)) + int.parse(paceStr.substring(6, 8));
        distance = length * pace;
      } else {
        distance = double.parse(myController.text);
      }
      double margin = 0;
      //If they selected Loops only
      if (outAndBack == "Loops") {
        while (margin <= desiredMargin + .01 ||
            (margin <= maxMargin + .01 && choosen.length < minRuns)) {
          for (Run run in allRunsList) {
            //Make sure you start in the right place and its not an out and back
            if (run.start.keys.toString() != "(" + _defaultStart + ")" && run.loop) {
              //See if they selected shorter runs only
              if (justDown) {
                //see if it is within the margin of error
                if (run.distance >= (distance - margin) && run.distance <= (distance + margin)) {
                  //make sure there wont be any repeats
                  if (!choosen.contains(run)) {
                    choosen.add(run);
                  }
                }
              } else {
                if (run.distance >= (distance - margin) && run.distance <= (distance)) {
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
      } else if (outAndBack == "Both") {
        while (margin <= desiredMargin + .01 ||
            (margin <= maxMargin + .01 && choosen.length < minRuns)) {
          for (Run run in allRunsList) {
            //Make sure you start in the right place
            if (run.start.keys.toString() != "(" + _defaultStart + ")") {
              //If its a loop
              if (run.loop) {
                //See if they selected shorter runs only
                if (justDown) {
                  //see if it is within the margin of error
                  if (run.distance >= (distance - margin) && run.distance <= (distance + margin)) {
                    //make sure there wont be any repeats
                    if (!choosen.contains(run)) {
                      choosen.add(run);
                    }
                  }
                } else {
                  if (run.distance >= (distance - margin) && run.distance <= (distance)) {
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
          if (run.start.keys.toString() != "(" + _defaultStart + ")" && !run.loop) {
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
        MaterialPageRoute(builder: (context) => const ChoosenRunScreen()),
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
                colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.1), BlendMode.dstATop),
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
                              keyboardType: const TextInputType.numberWithOptions(decimal: false),
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
                              keyboardType: const TextInputType.numberWithOptions(decimal: false),
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
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          controller: myController,
                          onSubmitted: (value) {
                            _findLongRun();
                          },
                          focusNode: focusNode1,
                        ),
                      ),

                //Padding
                const SizedBox(height: 20),
                const Text("Type of Run:"),
                DropdownButton(
                  items: oBValues.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  icon: const Icon(Icons.expand_more_rounded),
                  value: outAndBack,
                  onChanged: (String? value) {
                    setState(() {
                      outAndBack = value!;
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

//TODO: Button to plan a whole week - need to choose tempo, hard day, hill sprints etc., computer will auto divide the milage into 6 days
//Follow general pattern of easy, hard/workout, recovery, medium, hard/workout, long run
//TODO: button to toggle to time/pace mode on calendar?
//TODO: possibly get rid of calender bc I have the team feature
class _CalendarPageState extends State<CalendarPage> {
  late final ValueNotifier<List<Plan>> _selectedPlans;
  CalendarFormat _calendarFormat = CalendarFormat.twoWeeks;
  RangeSelectionMode _rangeSelectionMode =
      RangeSelectionMode.toggledOff; // Can be toggled on/off by longpressing a date
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  bool showAdd = false;
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final distanceController = TextEditingController();
  final panelController = PanelController();
  DateTime addDate = DateTime.now();
  final FocusNode focusNode1 = FocusNode();

  @override
  void initState() {
    super.initState();
    focusNode1.addListener(() {
      bool hasFocus = focusNode1.hasFocus;
      if (hasFocus && !Platform.isMacOS) {
        KeyboardOverlay.showOverlay(context);
      } else {
        KeyboardOverlay.removeOverlay();
      }
    });
    _selectedDay = _focusedDay;
    _selectedPlans = ValueNotifier(_getPlansForDay(_selectedDay!));
    //TODO: Fix bug with leftover events from old profiles
    FirebaseAuth.instance.idTokenChanges().listen((User? user) {
      if (user == null) {
        // ignore: prefer_collection_literals
        kPlans = LinkedHashMap<DateTime, dynamic>();
      } else {
        syncFromProfile();
      }
    });
  }

  @override
  void dispose() {
    _selectedPlans.dispose();
    super.dispose();
  }

  List<Plan> _getPlansForDay(DateTime day) {
    // Implementation example
    return kPlans[day] ?? [];
  }

  List<Plan> _getPlansForRange(DateTime start, DateTime end) {
    // Implementation example
    final days = daysInRange(start, end);

    return [
      for (final d in days) ..._getPlansForDay(d),
    ];
  }

  _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: _selectedDay ?? addDate,
        firstDate: kFirstDay,
        lastDate: kLastDay);
    if (picked != null && picked != addDate) {
      setState(() {
        addDate = picked;
      });
    }
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

      _selectedPlans.value = _getPlansForDay(selectedDay);
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
      _selectedPlans.value = _getPlansForRange(start, end);
    } else if (start != null) {
      _selectedPlans.value = _getPlansForDay(start);
    } else if (end != null) {
      _selectedPlans.value = _getPlansForDay(end);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Calendar'),
      ),
      drawer: const NavDrawer(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 8.0),
            //Calendar
            TableCalendar<Plan>(
              firstDay: kFirstDay,
              lastDay: kLastDay,
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              rangeStartDay: _rangeStart,
              rangeEndDay: _rangeEnd,
              calendarFormat: _calendarFormat,
              rangeSelectionMode: _rangeSelectionMode,
              eventLoader: _getPlansForDay,
              startingDayOfWeek: StartingDayOfWeek.sunday,
              calendarStyle: const CalendarStyle(
                // Use `CalendarStyle` to customize the UI
                outsideDaysVisible: false,
                markerDecoration: BoxDecoration(color: Colors.cyan, shape: BoxShape.circle),
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
            //display events for a day
            Flex(
              direction: Axis.vertical,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  fit: FlexFit.loose,
                  child: ValueListenableBuilder<List<Plan>>(
                    valueListenable: _selectedPlans,
                    builder: (context, value, _) {
                      return ListView.builder(
                        shrinkWrap: true,
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
                              // ignore: avoid_print
                              onLongPress: () {
                                showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        content: SizedBox(
                                          height: MediaQuery.of(context).size.height * .18,
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: <Widget>[
                                              TextButton(
                                                onPressed: () {
                                                  titleController.text = value[index].title;
                                                  descriptionController.text =
                                                      value[index].description;
                                                  distanceController.text =
                                                      value[index].distance.toString();
                                                  addDate = _selectedDay!;
                                                  showDialog(
                                                      context: context,
                                                      builder: (BuildContext context) {
                                                        return AlertDialog(
                                                          content: Stack(
                                                            children: [
                                                              Positioned(
                                                                right: 0,
                                                                bottom: 0,
                                                                child: FloatingActionButton(
                                                                  onPressed: () {
                                                                    if (titleController.text == "") {
                                                                      showDialog(
                                                                          context: context,
                                                                          builder:
                                                                              (BuildContext context) {
                                                                            return AlertDialog(
                                                                              content: const Text(
                                                                                  'Please enter a title'),
                                                                              actions: <Widget>[
                                                                                TextButton(
                                                                                  child: const Text(
                                                                                      'Ok'),
                                                                                  onPressed: () {
                                                                                    Navigator.of(
                                                                                            context)
                                                                                        .pop();
                                                                                  },
                                                                                ),
                                                                              ],
                                                                            );
                                                                          });
                                                                    } else if (descriptionController
                                                                            .text ==
                                                                        "") {
                                                                      showDialog(
                                                                          context: context,
                                                                          builder:
                                                                              (BuildContext context) {
                                                                            return AlertDialog(
                                                                              content: const Text(
                                                                                  'Please enter a description'),
                                                                              actions: <Widget>[
                                                                                TextButton(
                                                                                  child: const Text(
                                                                                      'Ok'),
                                                                                  onPressed: () {
                                                                                    Navigator.of(
                                                                                            context)
                                                                                        .pop();
                                                                                  },
                                                                                ),
                                                                              ],
                                                                            );
                                                                          });
                                                                    } else if (distanceController
                                                                            .text ==
                                                                        "") {
                                                                      showDialog(
                                                                          context: context,
                                                                          builder:
                                                                              (BuildContext context) {
                                                                            return AlertDialog(
                                                                              content: const Text(
                                                                                  'Please enter a distance'),
                                                                              actions: <Widget>[
                                                                                TextButton(
                                                                                  child: const Text(
                                                                                      'Ok'),
                                                                                  onPressed: () {
                                                                                    Navigator.of(
                                                                                            context)
                                                                                        .pop();
                                                                                  },
                                                                                ),
                                                                              ],
                                                                            );
                                                                          });
                                                                    } else {
                                                                      value[index] = Plan(
                                                                          titleController.text,
                                                                          descriptionController.text,
                                                                          double.parse(
                                                                              distanceController
                                                                                  .text));
                                                                      setState(() {});
                                                                      titleController.clear();
                                                                      descriptionController.clear();
                                                                      distanceController.clear();
                                                                      addDate = DateTime.now();
                                                                      Navigator.of(context).pop();
                                                                      Navigator.of(context).pop();
                                                                      syncToProfile();
                                                                    }
                                                                  },
                                                                  child: const Icon(Icons.save),
                                                                ),
                                                              ),
                                                              SizedBox(
                                                                width: MediaQuery.of(context)
                                                                        .size
                                                                        .width *
                                                                    .5,
                                                                height: MediaQuery.of(context)
                                                                        .size
                                                                        .height *
                                                                    .4,
                                                                child: Center(
                                                                  child: Column(
                                                                    mainAxisAlignment:
                                                                        MainAxisAlignment.center,
                                                                    children: <Widget>[
                                                                      TextField(
                                                                        controller: titleController,
                                                                        decoration:
                                                                            const InputDecoration(
                                                                          labelText: "Title",
                                                                          hintText:
                                                                              'Ex. "Medium Day"',
                                                                        ),
                                                                      ),
                                                                      //Description of run
                                                                      TextField(
                                                                        controller:
                                                                            descriptionController,
                                                                        maxLines: null,
                                                                        keyboardType:
                                                                            TextInputType.multiline,
                                                                        decoration:
                                                                            const InputDecoration(
                                                                          labelText: "Descripiton",
                                                                          hintText:
                                                                              'Ex. "Aerobic Run"',
                                                                        ),
                                                                      ),
                                                                      //Distance of run
                                                                      TextField(
                                                                        controller:
                                                                            distanceController,
                                                                        decoration:
                                                                            const InputDecoration(
                                                                          labelText: "Distance",
                                                                          hintText: 'Ex. "8"',
                                                                        ),
                                                                      ),
                                                                      //Date of run
                                                                      ElevatedButton(
                                                                        onPressed: () =>
                                                                            _selectDate(context),
                                                                        child:
                                                                            const Text('Select date'),
                                                                      ),

                                                                      TextButton(
                                                                          onPressed: () {
                                                                            setState(() {});
                                                                            titleController.clear();
                                                                            descriptionController
                                                                                .clear();
                                                                            distanceController
                                                                                .clear();
                                                                            addDate = DateTime.now();
                                                                            Navigator.of(context)
                                                                                .pop();
                                                                          },
                                                                          child:
                                                                              const Text('Cancel')),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                      });
                                                },
                                                child: const Text("Edit Run"),
                                              ),
                                              //Delet Run Button
                                              TextButton(
                                                onPressed: () {
                                                  showDialog(
                                                      context: context,
                                                      builder: (BuildContext context) {
                                                        return AlertDialog(
                                                          content: const Text(
                                                              "Are you sure you want to delete this Run?"),
                                                          actions: <Widget>[
                                                            //cancel
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.of(context).pop(),
                                                              child: const Text("Cancel"),
                                                            ),
                                                            //Delete run button
                                                            TextButton(
                                                              onPressed: () {
                                                                kPlans[_selectedDay]?.removeAt(index);
                                                                setState(() {});
                                                                Navigator.of(context).pop();
                                                                Navigator.of(context).pop();
                                                                syncToProfile();
                                                              },
                                                              child: const Text("Delete Run"),
                                                            ),
                                                          ],
                                                        );
                                                      });
                                                },
                                                child: const Text("Delete Run"),
                                              ),
                                              //Cancel Button
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                },
                                                child: const Text("Cancel"),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    });
                              },
                              title: Text('${value[index]}'),
                              leading: (value[index].toString().contains("bike"))
                                  ? const Icon(Icons.directions_bike)
                                  : const Icon(Icons.directions_run),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
            //Adding a run
            //TODO: Fix this, maybe by adding in the scroll view inside, or making some kind of custom popup widegt?
            //Use a Modal bottom sheet: https://api.flutter.dev/flutter/material/showModalBottomSheet.html
            Visibility(
              //Basically just get rid of the slidgin up widget on mac os
              child: (Platform.isMacOS)
                  ? (Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: <Widget>[
                              //Title of slide up
                              Text(
                                "Add a Run",
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary, fontSize: 20),
                                softWrap: true,
                              ),
                              //Title of run
                              SizedBox(
                                width: MediaQuery.of(context).size.width * .8,
                                child: TextField(
                                  controller: titleController,
                                  decoration: const InputDecoration(
                                    labelText: "Title",
                                    hintText: 'Ex. "Medium Day"',
                                  ),
                                ),
                              ),

                              //Description of run
                              SizedBox(
                                width: MediaQuery.of(context).size.width * .8,
                                child: TextField(
                                  controller: descriptionController,
                                  maxLines: null,
                                  keyboardType: TextInputType.multiline,
                                  decoration: const InputDecoration(
                                    labelText: "Descripiton",
                                    hintText: 'Ex. "Aerobic Run"',
                                  ),
                                  focusNode: focusNode1,
                                ),
                              ),
                              SizedBox(
                                width: MediaQuery.of(context).size.width * .8,
                                child: Row(
                                  children: <Widget>[
                                    //Distance of run
                                    SizedBox(
                                      width: MediaQuery.of(context).size.width * .35,
                                      child: TextField(
                                        controller: distanceController,
                                        decoration: const InputDecoration(
                                          labelText: "Distance",
                                          hintText: 'Ex. "8"',
                                        ),
                                      ),
                                    ),
                                    //Date of run
                                    SizedBox(
                                      width: MediaQuery.of(context).size.width * .35,
                                      child: ElevatedButton(
                                        onPressed: () => _selectDate(context),
                                        child: const Text('Select date'),
                                      ),
                                    ),
                                  ],
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                ),
                              ),
                              SizedBox(
                                width: MediaQuery.of(context).size.width * .8,
                                child:
                                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                  //Cancel Button
                                  TextButton(
                                      onPressed: () {
                                        showAdd = !showAdd;
                                        setState(() {});
                                        titleController.clear();
                                        descriptionController.clear();
                                        distanceController.clear();
                                        addDate = DateTime.now();
                                      },
                                      child: const Text('Cancel')),
                                  //Save button
                                  ElevatedButton(
                                    onPressed: () {
                                      if (titleController.text == "") {
                                        showDialog(
                                            context: context,
                                            builder: (BuildContext context) {
                                              return AlertDialog(
                                                content: const Text('Please enter a title'),
                                                actions: <Widget>[
                                                  TextButton(
                                                    child: const Text('Ok'),
                                                    onPressed: () {
                                                      Navigator.of(context).pop();
                                                    },
                                                  ),
                                                ],
                                              );
                                            });
                                      } else if (descriptionController.text == "") {
                                        showDialog(
                                            context: context,
                                            builder: (BuildContext context) {
                                              return AlertDialog(
                                                content: const Text('Please enter a description'),
                                                actions: <Widget>[
                                                  TextButton(
                                                    child: const Text('Ok'),
                                                    onPressed: () {
                                                      Navigator.of(context).pop();
                                                    },
                                                  ),
                                                ],
                                              );
                                            });
                                      } else if (distanceController.text == "") {
                                        showDialog(
                                            context: context,
                                            builder: (BuildContext context) {
                                              return AlertDialog(
                                                content: const Text('Please enter a distance'),
                                                actions: <Widget>[
                                                  TextButton(
                                                    child: const Text('Ok'),
                                                    onPressed: () {
                                                      Navigator.of(context).pop();
                                                    },
                                                  ),
                                                ],
                                              );
                                            });
                                      } else {
                                        addScheduledRun(
                                            titleController.text,
                                            descriptionController.text,
                                            double.parse(distanceController.text),
                                            addDate);
                                        showAdd = !showAdd;
                                        _getPlansForDay(_selectedDay!);
                                        setState(() {});
                                        titleController.clear();
                                        descriptionController.clear();
                                        distanceController.clear();
                                        addDate = DateTime.now();
                                      }
                                    },
                                    child: const Text("Add Run"),
                                  ),
                                ]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ))
                  : (SlidingUpPanel(
                      margin: const EdgeInsets.all(8),
                      maxHeight: MediaQuery.of(context).size.height * .5,
                      minHeight: MediaQuery.of(context).size.height * .3,
                      panelSnapping: false,
                      controller: panelController,
                      border: Border.all(color: Theme.of(context).colorScheme.onBackground),
                      borderRadius: const BorderRadius.all(
                        Radius.circular(10.0),
                      ),
                      panel: Stack(
                        children: [
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: <Widget>[
                                //Title of slide up
                                Text(
                                  "Add a Run",
                                  style: TextStyle(
                                      color: Theme.of(context).colorScheme.primary, fontSize: 20),
                                  softWrap: true,
                                ),
                                //Title of run
                                SizedBox(
                                  width: MediaQuery.of(context).size.width * .8,
                                  child: TextField(
                                    controller: titleController,
                                    decoration: const InputDecoration(
                                      labelText: "Title",
                                      hintText: 'Ex. "Medium Day"',
                                    ),
                                  ),
                                ),

                                //Description of run
                                SizedBox(
                                  width: MediaQuery.of(context).size.width * .8,
                                  child: TextField(
                                    controller: descriptionController,
                                    maxLines: null,
                                    keyboardType: TextInputType.multiline,
                                    decoration: const InputDecoration(
                                      labelText: "Descripiton",
                                      hintText: 'Ex. "Aerobic Run"',
                                    ),
                                    focusNode: focusNode1,
                                  ),
                                ),
                                SizedBox(
                                  width: MediaQuery.of(context).size.width * .8,
                                  child: Row(
                                    children: <Widget>[
                                      //Distance of run
                                      SizedBox(
                                        width: MediaQuery.of(context).size.width * .35,
                                        child: TextField(
                                          controller: distanceController,
                                          decoration: const InputDecoration(
                                            labelText: "Distance",
                                            hintText: 'Ex. "8"',
                                          ),
                                        ),
                                      ),
                                      //Date of run
                                      SizedBox(
                                        width: MediaQuery.of(context).size.width * .35,
                                        child: ElevatedButton(
                                          onPressed: () => _selectDate(context),
                                          child: const Text('Select date'),
                                        ),
                                      ),
                                    ],
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  ),
                                ),
                                SizedBox(
                                  width: MediaQuery.of(context).size.width * .8,
                                  child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        //Cancel Button
                                        TextButton(
                                            onPressed: () {
                                              showAdd = !showAdd;
                                              setState(() {});
                                              titleController.clear();
                                              descriptionController.clear();
                                              distanceController.clear();
                                              addDate = DateTime.now();
                                            },
                                            child: const Text('Cancel')),
                                        //Save button
                                        ElevatedButton(
                                          onPressed: () {
                                            if (titleController.text == "") {
                                              showDialog(
                                                  context: context,
                                                  builder: (BuildContext context) {
                                                    return AlertDialog(
                                                      content: const Text('Please enter a title'),
                                                      actions: <Widget>[
                                                        TextButton(
                                                          child: const Text('Ok'),
                                                          onPressed: () {
                                                            Navigator.of(context).pop();
                                                          },
                                                        ),
                                                      ],
                                                    );
                                                  });
                                            } else if (descriptionController.text == "") {
                                              showDialog(
                                                  context: context,
                                                  builder: (BuildContext context) {
                                                    return AlertDialog(
                                                      content:
                                                          const Text('Please enter a description'),
                                                      actions: <Widget>[
                                                        TextButton(
                                                          child: const Text('Ok'),
                                                          onPressed: () {
                                                            Navigator.of(context).pop();
                                                          },
                                                        ),
                                                      ],
                                                    );
                                                  });
                                            } else if (distanceController.text == "") {
                                              showDialog(
                                                  context: context,
                                                  builder: (BuildContext context) {
                                                    return AlertDialog(
                                                      content: const Text('Please enter a distance'),
                                                      actions: <Widget>[
                                                        TextButton(
                                                          child: const Text('Ok'),
                                                          onPressed: () {
                                                            Navigator.of(context).pop();
                                                          },
                                                        ),
                                                      ],
                                                    );
                                                  });
                                            } else {
                                              addScheduledRun(
                                                  titleController.text,
                                                  descriptionController.text,
                                                  double.parse(distanceController.text),
                                                  addDate);
                                              showAdd = !showAdd;
                                              _getPlansForDay(_selectedDay!);
                                              setState(() {});
                                              titleController.clear();
                                              descriptionController.clear();
                                              distanceController.clear();
                                              addDate = DateTime.now();
                                            }
                                          },
                                          child: const Text("Add Run"),
                                        ),
                                      ]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      color: Theme.of(context).scaffoldBackgroundColor,
                    )),
              visible: showAdd,
            ),
          ],
        ),
      ),

      //Add button
      floatingActionButton: Visibility(
        visible: !showAdd,
        child: FloatingActionButton(
          onPressed: () {
            showAdd = true;

            setState(() {});
          },
          child: const Icon(Icons.add),
        ),
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
      route: json['route'],
      distance: (json['distance'] is double) ? json['distance'] : json['distance'].toDouble(),
      elevation: (json['elevation gain'] == "")
          ? 'No Elevation Data Included'
          : json['elevation gain'].toString(),
      start: {json['starting place']: json['(long, lat)'].split(',')},
      loop: json['loop'],
      hill: json['hill repeats'],
      warmUp: json['warm up'],
      steepness: json['steepness'].toDouble(),
      hated: (json['hated']) ? (hateds.contains(json['route']) ? true : false) : false,
      favorite: (json['favorite']) ? (favorites.contains(json['route']) ? true : false) : false,
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

Future<List<Run>> fetchRun() async {
  List<Run> ret = [];
  CollectionReference _collectionRef = FirebaseFirestore.instance.collection('Runs');
  QuerySnapshot querySnapshot = await _collectionRef.get();
  final allData = querySnapshot.docs.map((doc) => doc.data()).toList();
  for (Object? data in allData) {
    Map<String, dynamic> dataMap = data as Map<String, dynamic>;
    ret.add(Run.fromMap(dataMap));
  }
  return ret;
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

//Menu bar
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
            leading: const SizedBox(width: 20, child: Icon(Icons.home)),
            title: const Text('Home'),
            onTap: () => {
              FirebaseAuth.instance.authStateChanges().listen((User? user) {
                if (user == null) {
                  //Signed out
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const MyHomePage(
                              title: "Run Finder",
                            )),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => MyHomePage(title: user.displayName! + "'s Run Finder")),
                  );
                }
              })
            },
          ),
          ListTile(
            leading: const SizedBox(width: 20, child: Icon(Icons.near_me)),
            title: const Text('Find a Location'),
            onTap: () => {
              Navigator.push(
                  context, MaterialPageRoute(builder: (context) => const FindLongRunScreen()))
            },
          ),
          ListTile(
            leading: const SizedBox(width: 20, child: Icon(Icons.list_alt)),
            title: const Text('List of Runs'),
            onTap: () =>
                {Navigator.push(context, MaterialPageRoute(builder: (context) => const RunScreen()))},
          ),
          ListTile(
            leading: const SizedBox(width: 20, child: Icon(Icons.calendar_today)),
            title: const Text('Calendar'),
            onTap: () => {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CalendarPage()),
              )
            },
          ),
          ListTile(
            leading: const SizedBox(width: 20, child: Icon(Icons.settings)),
            title: const Text('Settings'),
            onTap: () => {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              )
            },
          ),
          Visibility(
            visible: Platform.isMacOS,
            child: ListTile(
                leading: SizedBox(
                  width: 20,
                  child: Icon(Icons.groups,
                      color: (FirebaseAuth.instance.currentUser != null)
                          ? Theme.of(context).iconTheme.color
                          : Colors.grey),
                ),
                title: Text(
                  'Team',
                  style: TextStyle(
                      color: (FirebaseAuth.instance.currentUser != null)
                          ? Theme.of(context).iconTheme.color
                          : Colors.grey),
                ),
                onTap: () => {
                      if (FirebaseAuth.instance.currentUser != null)
                        {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const TeamPage()),
                          )
                        }
                      else
                        {
                          showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                      title: const Text("Must be logged in to access team feature"),
                                      actions: <Widget>[
                                        TextButton(
                                            onPressed: Navigator.of(context).pop,
                                            child: const Text("Ok"))
                                      ]))
                        }
                    }),
          ),
          ListTile(
            leading: const SizedBox(width: 20, child: Icon(Icons.person)),
            title: const Text('Profile'),
            onTap: () => {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              ),
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
          rightChunk = value.substring(4, 5) + value.substring(6, 7) + ":" + value.substring(7);
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

class Plan {
  final String title;
  final String description;
  final double distance;

  const Plan(this.title, this.description, this.distance);

  @override
  String toString() {
    return title + ": " + distance.toString() + " miles" "\n" + description;
  }

//What we're using in the teams database
  String toDatabaseString() {
    return title + ": " + description + ", " + distance.toString() + " miles";
  }

//not really json, but its close enough
  String toJson() {
    return title + ":" + description + ":" + distance.toString();
  }
}

//TODO: Possibly sync with garmin to have completed runs in calendar?

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

//Gets the location of the user
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

void addScheduledRun(String title, String description, double distance, DateTime date) {
  if (kPlans[date] != null) {
    kPlans[date]!.add(Plan(title, description, distance));
  } else {
    kPlans[date] = <Plan>[Plan(title, description, distance)];
  }
  syncToProfile();
}

//TODO: Implement this sync from cloud:
//When to do it tho? like all the time, will it replace duplicates?
//Do it when the user refreshes the page(through a swipe up) or starts the app or opens calendar page
void syncAssignedRunsFromTeam() async {}

void wontSync() {
  runApp(MaterialApp(
      home: AlertDialog(
    content: const Text("Error syncing to server."),
    actions: [
      TextButton(
          onPressed: () {
            main();
          },
          child: const Text("Try again"))
    ],
  )));
}

//Function to save all of users info, prefrences to the cloud(document with uid as name)
void syncToProfile() {
  User? user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    CollectionReference _collectionRef = FirebaseFirestore.instance.collection('Users');
    DocumentReference doc = _collectionRef.doc(user.uid);
    List<String> events = [];
    kPlans.forEach((key, value) {
      for (Plan plan in value) {
        events.add(key.toString() + ":" + plan.toJson());
      }
    });
    Map<String, dynamic> info = {
      "Favorites": favorites,
      "Hateds": hateds,
      "desiredMargin": desiredMargin,
      "_defaultStart": _defaultStart,
      "maxMargin": maxMargin,
      "justDown": justDown,
      "minRuns": minRuns,
      "kPlans": events,
      "coach": coach,
      "team": team,
      "group": group,
    };
    doc.set(info);
  }
}

//Function to get all data from the user's document(found through uid) and sync it to the device
void syncFromProfile() async {
  User? user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    CollectionReference _collectionRef = FirebaseFirestore.instance.collection('Users');
    Future<DocumentSnapshot<Object?>> doc = _collectionRef.doc(user.uid).get();
    Map<String, dynamic> data;
    doc.then((DocumentSnapshot documentSnapshot) {
      if (documentSnapshot.exists) {
        data = documentSnapshot.data() as Map<String, dynamic>;
        favorites = data["Favorites"].cast<String>();
        hateds = data["Hateds"].cast<String>();
        maxMargin = data["maxMargin"] as double;
        justDown = data["justDown"] as bool;
        minRuns = data["minRuns"] as int;
        desiredMargin = data["desiredMargin"] as double;
        _defaultStart = data["_defaultStart"] as String;
        List<String> events = data["kPlans"].cast<String>() ?? [];
        for (String plan in events) {
          int index = plan.indexOf(":", 20);
          int index2 = plan.indexOf(":", index + 1);
          int index3 = plan.indexOf(":", index2 + 1);
          DateTime date = DateTime.parse(plan.substring(0, index));
          if (!date.isBefore(kFirstDay) || !date.isAfter(kLastDay)) {
            String title = plan.substring(index + 1, index2);
            String description = plan.substring(index2 + 1, index3);
            double distance = double.parse(plan.substring(index3 + 1));
            Plan eventForm = Plan(title, description, distance);
            if (kPlans[date] != null) {
              if (kPlans[date].toString().contains(eventForm.toString()) == false) {
                kPlans[date]!.add(eventForm);
              }
            } else {
              kPlans[date] = <Plan>[eventForm];
            }
          }
        }
        coach = data["coach"];
        group = data["group"];
        team = data["team"];
      }
    });
  }
}
