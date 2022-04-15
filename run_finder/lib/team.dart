import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart' show NavDrawer, syncToProfile, team, coach, Plan, group;

//TODO: when they edit their name, have it update in the team as well as in their own profile
class TeamPage extends StatefulWidget {
  const TeamPage({Key? key}) : super(key: key);

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  @override
  Widget build(BuildContext context) {
    if (coach) {
      return (team == "None") ? const CreateTeam() : const CoachViewTeam();
    } else {
      return Scaffold(
        drawer: const NavDrawer(),
        appBar: AppBar(
          title: const Text("Team Page"),
        ),
        body: Center(
          child: Column(
            children: [
              (team == "None")
                  ? TextButton(
                      onPressed: () => findTeam(context),
                      child: Text("Join a Team",
                          style: TextStyle(color: Theme.of(context).colorScheme.onBackground)),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text("Your Team Is: " + team),
                        TextButton(
                          onPressed: () => findTeam(context),
                          child: Text("Change Team",
                              style: TextStyle(color: Theme.of(context).colorScheme.onBackground)),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      );
    }
  }
}

void editTeam(BuildContext context, void Function(void Function()) setState) {}

class CoachViewTeam extends StatefulWidget {
  const CoachViewTeam({Key? key}) : super(key: key);

  @override
  State<CoachViewTeam> createState() => _CoachViewTeamState();
}

class _CoachViewTeamState extends State<CoachViewTeam> {
  Map<String, List<Map<String, String>>> groups = {};
  Map<String, String> namesToUid = {};
  Map<String, List<String>> athletes = {};
  DateTime selectedDate = DateTime.now();
  Future<void> retrieveData() async {
    DocumentReference doc = FirebaseFirestore.instance.collection('Teams').doc(team);

    await doc.get().then((DocumentSnapshot documentSnapshot) {
      Map<String, dynamic> data = documentSnapshot.data() as Map<String, dynamic>;
      data.forEach(
        (key, value) {
          List<Map<String, String>> values = [];
          for (var element in (value as List<dynamic>)) {
            List<String> elements = (element as String).split(",");
            values.add({elements[0]: elements[1]});
            namesToUid[elements[0]] = elements[1];
            if (athletes[key] == null) {
              athletes[key] = [elements[0]];
            } else {
              athletes[key]!.add(elements[0]);
            }
          }
          groups[key] = values;
        },
      );
    });
  }

  DateTime mostRecentMonday(DateTime date) =>
      DateTime(date.year, date.month, date.day - (date.weekday - 1));

  //Get the runs for a specific day
  Future<Map<String, List<String>>> getRunsForDay(DateTime date) async {
    Map<String, List<String>> runs = {};

    String dateString = date.toString().substring(0, 10);
    DocumentReference doc = FirebaseFirestore.instance
        .collection('Teams')
        .doc(team)
        .collection('Scheduled Runs')
        .doc(dateString);
    await doc.get().then(
      (DocumentSnapshot documentSnapshot) {
        Map<String, dynamic> data =
            (documentSnapshot.data() != null) ? documentSnapshot.data() as Map<String, dynamic> : {};
        data.forEach((groupName, listOfRuns) {
          runs[groupName] = listOfRuns.cast<String>() ?? [];
        });
      },
    );

    return runs;
  }

  Future<DateTime> _selectDate(BuildContext context, DateTime addDate) async {
    final kToday = DateTime.now();
    final kFirstDay = DateTime(kToday.year, kToday.month - 3, kToday.day);
    final kLastDay = DateTime(kToday.year, kToday.month + 3, kToday.day);
    final DateTime? picked = await showDatePicker(
        context: context, initialDate: addDate, firstDate: kFirstDay, lastDate: kLastDay);
    if (picked != null && picked != addDate) {
      setState(() {
        addDate = picked;
      });
    }
    return addDate;
  }

  Widget _buildExpandableTile(String currentGroup, List<String> items) {
    return ExpansionTile(
      title: Text(
        currentGroup,
      ),
      children: <Widget>[
        SizedBox(
          height: items.length * 48,
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: ((context, index) {
              return ListTile(
                title: Text(
                  items[index],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildExpandableRow(Widget title, List<List<String>> items, List<double> widths) {
    if (items[1].isEmpty) {
      items[1] = List.generate(items[0].length, (index) => "");
    }
    if (items[2].isEmpty) {
      items[2] = List.generate(items[0].length, (index) => "");
    }
    return ExpansionTile(
      title: title,
      children: (items.isNotEmpty)
          ? <Widget>[
              SizedBox(
                height: items[0].length * 48,
                child: ListView.builder(
                  itemCount: items[0].length,
                  itemBuilder: ((context, index) {
                    return ListTile(
                      title: Row(
                        children: [
                          SizedBox(
                            width: widths[0],
                            child: Text(items[0][index]),
                          ),
                          SizedBox(
                            width: widths[1],
                            child: Text(items[1][index]),
                          ),
                          SizedBox(
                            width: widths[2],
                            child: Text(items[2][index]),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ]
          : [],
    );
  }

  Future<void> _addWeeklyMiles(DateTime monday) async {
    //function that will add up the miles for the week starting on given monday
    Map<String, List<String>> mileages = {};
    CollectionReference _collectionRef =
        FirebaseFirestore.instance.collection('Teams').doc(team).collection('Scheduled Runs');
    //Loop through the next 7 days
    for (int i = 0; i <= 7; i++) {
      String dateString = monday.add(Duration(days: i)).toString().substring(0, 10);
      DocumentReference doc = _collectionRef.doc(dateString);
      await doc.get().then((DocumentSnapshot documentSnapshot) {
        Map<String, dynamic> data =
            (documentSnapshot.data() != null) ? documentSnapshot.data() as Map<String, dynamic> : {};
        data.forEach((groupName, runs) {
          List<String> listOfRuns = runs.cast<String>();
          for (int j = 0; j < listOfRuns.length; j++) {
            String run = listOfRuns[j];

            if (run != "Not Completed" && run != "") {
              //essentially if j=0
              if (mileages[groupName] == null) {
                mileages[groupName] = [
                  run.substring(run.lastIndexOf(", ") + 2, run.lastIndexOf(" "))
                ];
              } else {
                double newMiles =
                    double.parse((run.substring(run.lastIndexOf(", ") + 2, run.lastIndexOf(" "))));
                mileages[groupName]![j] =
                    (double.parse(mileages[groupName]![j]) + newMiles).toString();
              }
            } else {
              if (mileages[groupName]!.length < j + 1) {
                mileages[groupName]!.add("0.0");
              }
            }
          }
        });
      });
    }

    FirebaseFirestore.instance
        .collection('Teams')
        .doc(team)
        .collection('Weekly Mileage')
        .doc(monday.toString().substring(0, 10))
        .update(mileages)
        .onError(((error, stackTrace) {
      FirebaseFirestore.instance
          .collection('Teams')
          .doc(team)
          .collection('Weekly Mileage')
          .doc(monday.toString().substring(0, 10))
          .set(mileages);
    }));
    setState(() {});
  }

  void _changeRunner(List<String> runnerInfo) async {
    //runnerInfo is [name, newGroup, uid]
    //TODO: when a runner is changed, will have to move all of their runs to thew new group(I want to kms that sounds so fucking annoying)
    DocumentReference _teamCollectionDoc = FirebaseFirestore.instance.collection("Teams").doc(team);
    String oldGroup = "";

    ///Steps to do:
    ///change group in runners document
    DocumentReference userDoc = FirebaseFirestore.instance.collection("Users").doc(runnerInfo[2]);

    await userDoc.get().then(((DocumentSnapshot documentSnapshot) {
      Map<String, dynamic> data = documentSnapshot.data() as Map<String, dynamic>;
      oldGroup = data["group"];
    }));
    await userDoc.update({"group": runnerInfo[1]});

    ///change team in groups
    int oldIndex = groups[oldGroup]!.indexOf({runnerInfo[0]: runnerInfo[2]});
    groups[oldGroup]!.remove({runnerInfo[0]: runnerInfo[2]});
    groups[runnerInfo[1]]!.add({runnerInfo[0]: runnerInfo[2]});

    ///change team on team document
    Map<String, List<String>> groupsFormatted = {};
    groups.forEach((String groupName, List<Map<String, String>> listOfAthletes) {
      for (Map<String, String> athlete in listOfAthletes) {
        if (athlete.keys.toList()[0] != runnerInfo[0] && groupName != oldGroup) {
          if (groupsFormatted[groupName] == null) {
            groupsFormatted[groupName] = [
              athlete.keys.toList()[0] + ',' + athlete.values.toList()[0]
            ];
          } else {
            groupsFormatted[groupName]!
                .add(athlete.keys.toList()[0] + ',' + athlete.values.toList()[0]);
          }
        }
      }
      if (listOfAthletes.isEmpty) {
        groupsFormatted[groupName] = [];
      }
    });

    print(groupsFormatted.toString());
    await _teamCollectionDoc.set(groupsFormatted);

    ///change runners data for every scheduled run
    //some code that loops through every document in the scheduled runs collection
    _teamCollectionDoc
        .collection("Scheduled Runs")
        .get()
        .then((QuerySnapshot<Map<String, dynamic>> value) {
      for (QueryDocumentSnapshot<Map<String, dynamic>> element in value.docs) {
        if (element.id != "blank") {
          Map<String, List<String>> data = element.data().cast<String, List<String>>();

          String run = data[oldGroup]![oldIndex];
          data[oldGroup]!.removeAt(oldIndex);
          data[runnerInfo[1]]!.add(run);
        }
      }
    });

    ///change runners data for every weekly mileage
    ///call retrieve data to fix everything, maybe even will have to add miles
  }

//allows the coach to assign runs to the team
  void assignRun() async {
    List<TableRow> tableRows = [
      TableRow(
        children: <Widget>[
          Text(
            "Group",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            "Title",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            "Descripiton",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            "Distance",
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    ];
    final allDescriptionController = TextEditingController();
    final allTitleController = TextEditingController();
    final allDistanceController = TextEditingController();
    List<String> groupNames = [];
    Map<String, List<TextEditingController>> controllers = {
      "description": <TextEditingController>[],
      "title": <TextEditingController>[],
      "distance": <TextEditingController>[]
    };

    //loop thorugh and make an iddividual row for each group
    for (String groupName in groups.keys) {
      if (groupName != "Coaches") {
        final descriptionController = TextEditingController();
        controllers["description"]!.add(descriptionController);
        final titleController = TextEditingController();
        controllers["title"]!.add(titleController);
        final distanceController = TextEditingController();
        controllers["distance"]!.add(distanceController);
        groupNames.add(groupName);
        tableRows.add(
          TableRow(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(5, 15, 5, 5),
                child: Text(
                  groupName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextField(
                controller: titleController,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: TextField(
                  controller: descriptionController,
                ),
              ),
              TextField(
                controller: distanceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
        );
      }
    }
    //All gorups rows
    tableRows.insert(
      1,
      TableRow(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(5, 15, 5, 5),
            child: Text(
              "All Groups",
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          TextField(
            controller: allTitleController,
            decoration: const InputDecoration(hintText: "Ex. Recovery Day"),
            onChanged: (value) {
              //So i flipped the fuck out when this worked, basically it just makes all the other textfields change to the "all groups" avlue - WITHOUT CALLING SETSTAE!!!!
              //I thought it would so f***** hard to not lose valuse and send the updates!!!!
              //V. happy abt this code, also very concise
              for (TextEditingController element in controllers["title"]!) {
                element.text = value;
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: TextField(
              controller: allDescriptionController,
              decoration: const InputDecoration(hintText: "Recovery Pace - go slow"),
              onChanged: (value) {
                for (TextEditingController element in controllers["description"]!) {
                  element.text = value;
                }
              },
            ),
          ),
          TextField(
            controller: allDistanceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: "6"),
            onChanged: (value) {
              for (TextEditingController element in controllers["distance"]!) {
                element.text = value;
              }
            },
          ),
        ],
      ),
    );
    DateTime addDate = selectedDate;

    //Actual UI Dsiplay
    showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ListView(
                children: <Widget>[
                  Center(
                    child: Text(
                      "Assign a Run",
                      style: Theme.of(context).textTheme.headline4,
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  Table(
                    columnWidths: const {
                      0: FractionColumnWidth(.15),
                      1: FractionColumnWidth(.25),
                      2: FractionColumnWidth(.33),
                      3: FractionColumnWidth(.1),
                    },
                    children: tableRows,
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  Row(
                    children: [
                      TextButton(
                          onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                      ElevatedButton(
                          onPressed: () async {
                            //Code to actually assign the run to the athletes
                            //Need to be careful and fill in the lengths correctly, make the doucment titles the right way etc as i had made before, should be crazy fun
                            //Start by making a friestore instance to improve latency
                            DocumentReference teamDoc =
                                FirebaseFirestore.instance.collection("Teams").doc(team);
                            CollectionReference schedRunsCollection =
                                teamDoc.collection("Scheduled Runs");

                            String addDateString = addDate.toString().substring(0, 10);
                            DateTime monday = mostRecentMonday(addDate);
                            Map<String, List<String>> groupsToRuns = {};
                            //Then loop through every group on the team
                            for (String groupName in groupNames) {
                              int index = groupNames.indexOf(groupName);
                              int num = groups[groupName]!.length;

                              //Stuff to get scheduled runs working
                              if (controllers["title"]![index].text != "" &&
                                  controllers["description"]![index].text != "" &&
                                  controllers["distance"]![index].text != "") {
                                Plan planned = Plan(
                                  controllers["title"]![index].text,
                                  controllers["description"]![index].text,
                                  double.parse(controllers["distance"]![index].text),
                                );
                                groupsToRuns[groupName] = [planned.toDatabaseString()];
                                while (groupsToRuns[groupName]!.length <= num) {
                                  groupsToRuns[groupName]!.add("Not Completed");
                                }
                              }
                            }

                            schedRunsCollection.doc(addDateString).update(groupsToRuns).onError(
                                (error, stackTrace) =>
                                    schedRunsCollection.doc(addDateString).set(groupsToRuns));

                            await _addWeeklyMiles(monday);
                            //at the end pop the dialog and call setState
                            Navigator.pop(context);
                            setState(() {});
                          },
                          child: const Text("Assign")),
                      IconButton(
                        onPressed: () async {
                          addDate = await _selectDate(context, addDate);
                        },
                        icon: const Icon(Icons.today),
                      ),
                    ],
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  )
                ],
              ),
            ),
          );
        });
  }

  void assignRunners() {
    List<List<String>> athletesToGroups = []; //Lists of [name, group, uid] for each athlete/coach
    for (String groupName in athletes.keys) {
      for (String athlete in athletes[groupName]!) {
        athletesToGroups.add([athlete, groupName, namesToUid[athlete]!]);
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: ListView.builder(
              itemCount: athletesToGroups.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Row(
                    children: [
                      Text(athletesToGroups[index][0]),
                      DropdownButton(
                          value: athletesToGroups[index][1],
                          items: groups.keys.map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? value) {
                            athletesToGroups[index][1] = value!;
                            _changeRunner(athletesToGroups[index]);
                            setState(() {});
                          })
                    ],
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<Map<String, List<String>>> getMileagesForWeek(DateTime monday) async {
    Map<String, List<String>> mileages = {};
    String dateString = monday.toString().substring(0, 10);
    DocumentReference doc = FirebaseFirestore.instance
        .collection('Teams')
        .doc(team)
        .collection('Weekly Mileage')
        .doc(dateString);
    await doc.get().then((DocumentSnapshot documentSnapshot) {
      Map<String, dynamic> data =
          (documentSnapshot.data() != null) ? documentSnapshot.data() as Map<String, dynamic> : {};
      data.forEach((groupName, listOfRuns) {
        mileages[groupName] = listOfRuns.cast<String>() ?? [];
      });
    });
    return mileages;
  }

//Function to dynamically build the rows of the table
  Future<List<Widget>> generateTable() async {
    if (groups.isEmpty) {
      await retrieveData();
    }
    Size size = MediaQuery.of(context).size;
    double coulmn1Width = size.width * .3;
    double coulmn2Width = size.width * .5;
    double coulmn3Width = size.width * .1;
    Map<int, String> weekdays = {
      1: "Mon",
      2: "Tue",
      3: "Wed",
      4: "Thur",
      5: "Fri",
      6: "Sat",
      7: "Sun"
    };
    List<Widget> tableRows = [
      //Default Header Table Row
      Container(
        decoration: const BoxDecoration(
          color: Color.fromARGB(255, 75, 75, 75),
          boxShadow: [
            BoxShadow(
              color: Color.fromARGB(255, 30, 30, 30),
              spreadRadius: 5,
              blurRadius: 9,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            //Assign runs button
            SizedBox(
              width: coulmn1Width,
              child: Padding(
                padding:
                    EdgeInsets.symmetric(vertical: size.height * .01, horizontal: size.width * .07),
                child: ElevatedButton(onPressed: () => assignRun(), child: const Text("Assign Run")),
              ),
            ),
            //Date and ability to go back and forth
            SizedBox(
              width: coulmn2Width,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      selectedDate = selectedDate.subtract(const Duration(days: 1));
                      setState(() {});
                    },
                    icon: const Icon(Icons.west),
                  ),
                  TextButton(
                      onPressed: (() => setState(() {
                            selectedDate = DateTime.now();
                          })),
                      child: Text(
                        ((selectedDate.toString().substring(0, 10) ==
                                    DateTime.now().toString().substring(0, 10))
                                ? "Today, "
                                : "") +
                            weekdays[selectedDate.weekday]! +
                            " " +
                            selectedDate.month.toString() +
                            "/" +
                            selectedDate.day.toString(),
                        style: TextStyle(color: Theme.of(context).colorScheme.onBackground),
                      )),
                  IconButton(
                    onPressed: () {
                      selectedDate = selectedDate.add(const Duration(days: 1));
                      setState(() {});
                    },
                    icon: const Icon(Icons.east),
                  ),
                ],
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
              ),
            ),
            //Weekly Mileage
            SizedBox(
              width: coulmn3Width,
              child: Padding(
                padding:
                    EdgeInsets.symmetric(vertical: size.height * .01, horizontal: size.width * .001),
                child: const Center(child: Text("Weekly Mileage")),
              ),
            ),
            IconButton(
              onPressed: assignRunners,
              icon: const Icon(Icons.group_add),
              tooltip: "Assign Runners To Groups",
            ),
          ],
        ),
      )
    ];

    List<String> groupsNames = groups.keys.toList();
    Map<String, List<String>> groupsToRuns = await getRunsForDay(selectedDate);

    Map<String, List<String>> weeklyMileages =
        await getMileagesForWeek(mostRecentMonday(selectedDate));

    for (String groupName in groupsNames) {
      if (groupName != "Coaches") {
        tableRows.add(_buildExpandableRow(
            Row(
              children: [
                //Name of runner/group
                SizedBox(
                  width: coulmn1Width,
                  child: Text(groupName),
                ),
                //Run
                SizedBox(
                  width: coulmn2Width,
                  child: Text(groupsToRuns[groupName]?[0] ?? ""),
                ),
                //Weekly Mileage
                SizedBox(
                  width: coulmn3Width,
                  child: Text(weeklyMileages[groupName]?[0] ?? ""),
                ),
              ],
            ),
            [
              athletes[groupName] ?? [],
              groupsToRuns[groupName]?.sublist(1) ?? [],
              weeklyMileages[groupName]?.sublist(1) ?? []
            ],
            [
              coulmn1Width,
              coulmn2Width,
              coulmn3Width
            ]));
      }
    }
    tableRows.add(_buildExpandableTile("Coaches", athletes["Coaches"]!));
    return tableRows;
  }

  @override
  Widget build(BuildContext context) {
    double _width = MediaQuery.of(context).size.width;
    double _height = MediaQuery.of(context).size.height;

    Future<List<Widget>> tableRows = generateTable();

    return Scaffold(
      drawer: const NavDrawer(),
      appBar: AppBar(
        title: Text(team),
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
              fit: BoxFit.fitHeight,
              invertColors: false,
              colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.1), BlendMode.dstATop),
              image: const AssetImage('assets/Map.jpeg')),
        ),
        child: Center(
          child: SizedBox(
            width: _width,
            height: _height,
            child: FutureBuilder<List<Widget>>(
                future: tableRows,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return ListView(children: snapshot.data!);
                  } else {
                    return const Center(
                      child: SizedBox(
                        width: 60,
                        height: 60,
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                }),
          ),
        ),
      ),
    );
  }
}

class CreateTeam extends StatefulWidget {
  const CreateTeam({Key? key}) : super(key: key);

  @override
  State<CreateTeam> createState() => _CreateTeamState();
}

class _CreateTeamState extends State<CreateTeam> {
  final nameController = TextEditingController();
  final ScrollController _controller = ScrollController();
  List<String> groups = ["General"];
  String teamName = "Team Name";
// This is what you're looking for!
  void _scrollDown() {
    _controller.animateTo(
      _controller.position.maxScrollExtent + 75,
      duration: const Duration(seconds: 1),
      curve: Curves.fastOutSlowIn,
    );
  }

  void _scrollUp() {
    _controller.animateTo(
      _controller.position.maxScrollExtent - 75,
      duration: const Duration(seconds: 1),
      curve: Curves.fastOutSlowIn,
    );
  }

  @override
  Widget build(BuildContext context) {
    double listHeight = MediaQuery.of(context).size.height * .55;
    return Scaffold(
        drawer: const NavDrawer(),
        appBar: AppBar(
          title: const Text("Create a Team"),
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(30, 20, 30, 0),
          child: Center(
            child: Column(
              children: <Widget>[
                //Team name
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    label: Text(teamName),
                  ),
                  onSubmitted: (value) {
                    teamName = value;
                    setState(() {});
                  },
                ),
                //Mileage Groups
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    "Mileage Groups",
                    style: TextStyle(fontSize: 20),
                  ),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width - 60,
                  height: listHeight,
                  child: ListView.builder(
                    controller: _controller,
                    itemCount: groups.length,
                    itemBuilder: ((context, index) {
                      final myController = TextEditingController();
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.5),
                        child: Container(
                          width: MediaQuery.of(context).size.width - 60,
                          height: 75,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
                            child: Stack(
                              children: [
                                TextField(
                                  onSubmitted: ((value) {
                                    groups[index] = value;

                                    setState(() {});
                                  }),
                                  controller: myController,
                                  decoration: InputDecoration(
                                    label: Text(groups[index]),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  child: IconButton(
                                      onPressed: () {
                                        groups[index] = myController.text;
                                        setState(() {});
                                      },
                                      icon: const Icon(Icons.done)),
                                )
                              ],
                            ),
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Theme.of(context).colorScheme.onPrimary),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: <Widget>[
                        //Add group button
                        Visibility(
                          visible: groups.length < 10,
                          child: IconButton(
                              onPressed: () {
                                groups.add("Group #" + (groups.length + 1).toString());
                                setState(() {});
                                if ((groups.length * 80) - 80 > listHeight) {
                                  _scrollDown();
                                }
                              },
                              icon: const Icon(Icons.add)),
                        ),
                        const SizedBox(
                          width: 5,
                        ),
                        //subtract group button
                        Visibility(
                          visible: groups.length > 1,
                          child: IconButton(
                              onPressed: () {
                                groups.removeLast();
                                setState(() {});
                                if ((groups.length * 80) > listHeight) {
                                  _scrollUp();
                                }
                              },
                              icon: const Icon(Icons.remove)),
                        )
                      ],
                    ),
                    ElevatedButton(
                        onPressed: () {
                          CollectionReference _collectionRef =
                              FirebaseFirestore.instance.collection('Teams');
                          DocumentReference doc = _collectionRef.doc(teamName);
                          doc.get().then((DocumentSnapshot documentSnapshot) async {
                            //Check if the document exists or not
                            //If it does, suggest they try a new name
                            if (documentSnapshot.exists) {
                              showDialog(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      title: const Text("Name of team already exists"),
                                      content: const Text("Try changing the name"),
                                      actions: [
                                        TextButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                            },
                                            child: const Text("Ok"))
                                      ],
                                    );
                                  });
                            } else if (groups.contains("Coaches")) {
                              showDialog(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      title: const Text('Cannot call a group "Coaches"'),
                                      content: const Text(
                                          "Try changing the name(don't worry, \nthere is a way to add coaches later)"),
                                      actions: [
                                        TextButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                            },
                                            child: const Text("Ok"))
                                      ],
                                    );
                                  });
                            } else if (groups.contains("Unassigned")) {
                              showDialog(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      title: const Text('Cannot call a group "Unassigned"'),
                                      content: const Text(
                                          "Try changing the name(this is where\nnew runners automatically go)"),
                                      actions: [
                                        TextButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                            },
                                            child: const Text("Ok"))
                                      ],
                                    );
                                  });
                            } else {
                              User user = FirebaseAuth.instance.currentUser!;

                              Map<String, dynamic> data = {
                                "Coaches": [user.displayName! + "," + user.uid],
                                "Unassigned": []
                              };
                              for (var element in groups) {
                                data[element] = [];
                              }
                              await doc.set(data);
                              await doc.collection("Scheduled Runs").add({});
                              await doc.collection("Weekly Mileage").add({});
                              team = teamName;
                              group = "Coaches";
                              syncToProfile();
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Team Succesfully Created")));
                            }
                          });
                        },
                        child: const Text("Create Team"))
                  ],
                )
                //Logo/profile pics?
                //Descripiton
              ],
            ),
          ),
        ));
  }
}

void findTeam(context) {
  showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Column(
                children: const <Widget>[
                  SizedBox(
                    height: 10,
                  ),
                  Text("Join, Change, or Leave a Team"),
                ],
              ),
            ),
          ),
        );
      });
}
