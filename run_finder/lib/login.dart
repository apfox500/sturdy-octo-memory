import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutterfire_ui/auth.dart';
import 'main.dart' show MyHomePage, syncFromProfile, syncToProfile, coach;

//TODO: Make changing coach/athlete status invisible if they are already in team
String accountTypeText = "Athlete";

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      // If the user is already signed-in, use it as initial data
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        // User is not signed in
        if (!snapshot.hasData) {
          return SignInScreen(
            providerConfigs: const [
              EmailProviderConfiguration(),
              GoogleProviderConfiguration(
                  clientId:
                      '392360097024-bmhramlnsig8cc0b8ev6mgc70sg3172l.apps.googleusercontent.com'),
            ],
            headerBuilder: (context, constraints, _) {
              return AppBar(
                title: const Text(""),
                leading: IconButton(
                  icon: const Icon(Icons.home),
                  onPressed: () {
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
                              builder: (context) =>
                                  MyHomePage(title: user.displayName! + "'s Run Finder")),
                        );
                      }
                    });
                  },
                ),
              );
            },
            headerMaxExtent: 50,
            showAuthActionSwitch: false,
          );
        }
        if (snapshot.data?.uid != null) {
          syncFromProfile();
        }
        // Render your application if authenticated
        return const ProfileScreen(
          /* children: <Widget>[
            const SizedBox(
              height: 20,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(accountTypeText),
                Switch(
                  value: coach,
                  onChanged: (value) {
                    coach = value;
                    syncToProfile();
                    if (value) {
                      accountTypeText = 'Coach';
                    } else {
                      accountTypeText = 'Athlete';
                    }
                    setState(() {});
                  },
                )
              ],
            ),
          ], */
          providerConfigs: const [],
        );
      },
    );
  }
}
