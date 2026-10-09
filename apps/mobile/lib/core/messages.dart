/// Every text the app shows, one class per language. A text missing in one
/// language is a compile error. Web and API have theirs in
/// packages/shared/src/messages.ts.
enum AppLocale {
  de(De()),
  en(En());

  const AppLocale(this.messages);
  final Messages messages;
}

abstract class Messages {
  const Messages();

  String get madeBy;

  /// Label of the language button, in the language it switches to
  String get otherLanguage;
  String get offline;
  String serverError(int status);
  String get loginIntro;
  String get codeSent;
  String get email;
  String get code;
  String get sendCode;
  String get logIn;
  String get otherEmail;
  String get locationDenied;
  String get locationUnavailable;
  String get myLocation;
  String get profile;
  String get name;
  String get save;
  String get saved;
  String get logOut;
  String get reportBug;
  String get giveFeedback;
  String get testMode;
  String get testModeHint;
  String get bugPlaceholder;
  String get ideaPlaceholder;
  String get removeScreenshot;
  String get markSpot;
  String get markHint;
  String get done;
  String get cancel;
  String get sentAlong;
  String get contextPage;
  String get contextDevice;
  String get contextWindow;
  String get contextLanguage;
  String get contextErrors;
  String repliesTo(String email);
  String get send;
  String get feedbackThanks;
}

class De extends Messages {
  const De();

  @override
  String get madeBy => 'ein Werkzeug von';
  @override
  String get otherLanguage => 'English';
  @override
  String get offline => 'Keine Verbindung zum Server';
  @override
  String serverError(int status) => 'Serverfehler ($status)';
  @override
  String get loginIntro => 'Kein Passwort nötig, wir schicken dir einen Code per Mail.';
  @override
  String get codeSent => 'Wir haben dir einen 6-stelligen Code geschickt.';
  @override
  String get email => 'E-Mail';
  @override
  String get code => 'Code';
  @override
  String get sendCode => 'Code schicken';
  @override
  String get logIn => 'Anmelden';
  @override
  String get otherEmail => 'Andere E-Mail / neuen Code';
  @override
  String get locationDenied => 'Standort nicht freigegeben';
  @override
  String get locationUnavailable => 'Standort nicht verfügbar';
  @override
  String get myLocation => 'Mein Standort';
  @override
  String get profile => 'Profil';
  @override
  String get name => 'Name';
  @override
  String get save => 'Speichern';
  @override
  String get saved => 'Gespeichert';
  @override
  String get logOut => 'Abmelden';
  @override
  String get reportBug => 'Fehler melden';
  @override
  String get giveFeedback => 'Feedback geben';
  @override
  String get testMode => 'Testmodus';
  @override
  String get testModeHint => 'Zeigt den Käfer-Knopf, mit dem du Fehler samt Screenshot meldest.';
  @override
  String get bugPlaceholder => 'Was ist passiert? Was hast du erwartet?';
  @override
  String get ideaPlaceholder => 'Was fehlt dir, was wünschst du dir, was gefällt dir?';
  @override
  String get removeScreenshot => 'Screenshot entfernen';
  @override
  String get markSpot => 'Stelle markieren';
  @override
  String get markHint => 'Zieh einen Rahmen um die Stelle';
  @override
  String get done => 'Fertig';
  @override
  String get cancel => 'Abbrechen';
  @override
  String get sentAlong => 'Was mitgeschickt wird';
  @override
  String get contextPage => 'Seite';
  @override
  String get contextDevice => 'Gerät';
  @override
  String get contextWindow => 'Fenster';
  @override
  String get contextLanguage => 'Sprache';
  @override
  String get contextErrors => 'Letzte Fehler';
  @override
  String repliesTo(String email) => 'Antworten bekommst du per Mail an $email.';
  @override
  String get send => 'Senden';
  @override
  String get feedbackThanks => 'Danke! Wir melden uns per Mail.';
}

class En extends Messages {
  const En();

  @override
  String get madeBy => 'a tool by';
  @override
  String get otherLanguage => 'Deutsch';
  @override
  String get offline => 'No connection to the server';
  @override
  String serverError(int status) => 'Server error ($status)';
  @override
  String get loginIntro => "No password needed, we'll email you a code.";
  @override
  String get codeSent => 'We sent you a 6-digit code.';
  @override
  String get email => 'Email';
  @override
  String get code => 'Code';
  @override
  String get sendCode => 'Send code';
  @override
  String get logIn => 'Log in';
  @override
  String get otherEmail => 'Other email / new code';
  @override
  String get locationDenied => 'Location access not granted';
  @override
  String get locationUnavailable => 'Location unavailable';
  @override
  String get myLocation => 'My location';
  @override
  String get profile => 'Profile';
  @override
  String get name => 'Name';
  @override
  String get save => 'Save';
  @override
  String get saved => 'Saved';
  @override
  String get logOut => 'Log out';
  @override
  String get reportBug => 'Report a bug';
  @override
  String get giveFeedback => 'Give feedback';
  @override
  String get testMode => 'Test mode';
  @override
  String get testModeHint => 'Shows the bug button for reporting bugs with a screenshot.';
  @override
  String get bugPlaceholder => 'What happened? What did you expect?';
  @override
  String get ideaPlaceholder => 'What are you missing, what would you like, what do you enjoy?';
  @override
  String get removeScreenshot => 'Remove screenshot';
  @override
  String get markSpot => 'Mark the spot';
  @override
  String get markHint => 'Drag a frame around the spot';
  @override
  String get done => 'Done';
  @override
  String get cancel => 'Cancel';
  @override
  String get sentAlong => 'What gets sent along';
  @override
  String get contextPage => 'Page';
  @override
  String get contextDevice => 'Device';
  @override
  String get contextWindow => 'Window';
  @override
  String get contextLanguage => 'Language';
  @override
  String get contextErrors => 'Recent errors';
  @override
  String repliesTo(String email) => 'Replies reach you by email at $email.';
  @override
  String get send => 'Send';
  @override
  String get feedbackThanks => "Thanks! We'll get back to you by email.";
}
