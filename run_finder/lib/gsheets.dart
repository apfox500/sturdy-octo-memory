// ignore_for_file: avoid_print

import 'package:gsheets/gsheets.dart';

// your google auth credentials
const _credentials = r'''
{
  "type": "service_account",
  "project_id": "gsheets-338919",
  "private_key_id": "08164f7a9846a6e7e2ecb7acb1b3c14f0790fb4c",
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQCefm/WAqIQafAp\nQsGGQfc2oq8FXxZfydPI2wDr5cKe/SH8yplyNz1Jqm4CrufRrRWElB7LmCa6Fdb2\nKZALao4AG2hjSMkzxjFjU2zTfyUG0mPFClunPTC5nEhbiRgGHl9u99lxhm1XR/Ko\nijeYDWHxwJOLvaAIPe8+n2V2JNdDMRNhEc8uAE4YZIA87XsUZS8nybzbt4DGIPPl\nRwMDZrIk6pgBwG3HKtHEZ1iSR9HNuWqwiM9AzqIqGu8dcNrjsFwczgdx+yHsybkh\ndEBKSdqbFIGtFQTTi0sTDj0tLhvayqVzsExrdP697eW8mx4+HtEAFqhdn06h4OEk\nykBOCCR/AgMBAAECggEAK0rzJnyaoywk10huT0uGiQyADVIPbQPWz0cPJeChPEd9\nuKzopDu1iIE+wonfNbV3KrtA/DDn5y2fBaeNuqiU+C+EYJZZq0RIak6367+PsCDY\n8tIk/fYncJPhaet1Pfqe69NUuH9VL6GuBV6X1/dT2TLWurWF2Kp+RtdIYjCnAimf\n72GqSv6YFWpjrVUCCpcvmPypw9VwRri5HKT8NpdcqxGfYz7pEwZsrPar7QPrTucq\naR4OWDD03MUlFNccYWH3UAWn9bJtlAS4Q9tuTIGd+ltFfRxkRT97FvwDSL7Dii4I\nnY1c4637VE81vyA7YhxENRnY8PeC8uQIGzDfJOUIYQKBgQDSruWXUf4KYZaUGxN4\nLb+b+ITiK4+78HVoanbm+1pEVpbAmOQ97hnh4ygEc/kM6nZZQ2QgmKxlxKMAXy4x\ndrUeqccjXaYCBLdZMgk/Ja/R+MpCmRF4bjokScjRULXl25gy6Bu1taO59Se1vS1L\nhzCVVzCzc0u974ywDadU6hyTXwKBgQDAlccXAkki9W0zJS5UKXoQI8ZZP1QtbRG7\nNaA2Sw1noQ/1K7inHWTT8gukHqcy2L6OLCmS1Od7TQk4bTeC7c1j0VMghcIj8KXW\nU+lrH+04Rr/FGpur4/yuT/VxK47EDwFUBtumDABJ3SqE0spVL+6UMFKwlUoQUpZj\ngrvHl6gi4QKBgQCzwsLmv/DQDsAaEpgkHHS2se8/wwdaxiqHMv/MyX4VfQQXxNxJ\n8xRmZhlI42MGoC7mrteJ8Hp4QrUJpiyVy8FyLk5ZYJg6dKe0FTtKg+9maq648D21\n0ecN+167KfBp9VoBZYXvHtJZ4lFFgepZ3TmY0tIc6y0fHHuf46Z4j2BeZQKBgQC7\nX/748AxgqxG4NXDCCijtEyGlK+ym1fvufdqHeLZuIVL5Y7ShRAQaAuI4qGpdGm0s\nvuMkLWmbmfRipkDgbqbre3q5peqiNT3lLndo9wNDQfLLv3u+3m+22a0gkxSwxTix\nnIqRIBQXycvYt46NG7mxDOMnU9lf0DrqTwSMyY2ZgQKBgGNiOU4iV4UjU6oHQcvc\nzkRjIkRt9a+LJYzW7Q7fcVKz5kANUoyPgqxR5lHdfvm1sX1Femwbhf4fUpZGnnFN\nMSx4XNRPRYlAcme/fAIBk15udhJUFICmcpMXp5LrHWWiOGeiYA4mxs2vHky71yQZ\nXJEd8ET3146IT0N+LivzKgtF\n-----END PRIVATE KEY-----\n",
  "client_email": "sheets@gsheets-338919.iam.gserviceaccount.com",
  "client_id": "103972527287883260723",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/sheets%40gsheets-338919.iam.gserviceaccount.com"

}
''';

// your spreadsheet id
const _spreadsheetId = '1M3RHXHqew6WZuiji17LUbOSj85W29EI8LNaPyI2R7EI';

void main() async {
  // init GSheets
  final gsheets = GSheets(_credentials);
  // fetch spreadsheet by its id
  final ss = await gsheets.spreadsheet(_spreadsheetId);
  // get worksheet by its title
  final sheet = ss.worksheetByTitle('products');

  print(await sheet?.values.row(1));
}
