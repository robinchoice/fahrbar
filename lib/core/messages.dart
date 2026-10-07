import 'package:flutter/widgets.dart';

/// Every text the app shows, one class per language. A text missing in one
/// language is a compile error.
enum AppLocale {
  de(De()),
  en(En());

  const AppLocale(this.messages);
  final Messages messages;
}

extension MessagesOf on BuildContext {
  /// Texts in the language MaterialApp currently runs in.
  Messages get t =>
      AppLocale.values.asNameMap()[Localizations.localeOf(this).languageCode]?.messages ?? const De();
}

String _two(int n) => n.toString().padLeft(2, '0');

abstract class Messages {
  const Messages();

  // Sender line
  String get madeBy;

  /// Label of the language button, in the language it switches to
  String get otherLanguage;

  // Formats
  String money(double amount, String currency);
  String date(DateTime d);
  String dateTime(DateTime d);
  String error(Object e);
  String rating(double value);

  // Login
  String get logIn;
  String get createAccount;
  String get email;
  String get password;
  String get confirmEmail;
  String get signUp;
  String get or;
  String get withApple;
  String get withGoogle;
  String get haveAccount;
  String get noAccount;

  // Map
  String get locationOff;
  String get locationDenied;
  String get locationUnavailable;
  String showingFreiburg(String reason);
  String get searchCar;
  String get findDriver;
  String get profile;
  String get myLocation;
  String get searchingCars;
  String get noCarsNearby;
  String carsNearby(int count);
  String driversNearby(int count);
  String get tabCar;
  String get tabDriver;
  String get noCarFree;
  String markerPrice(double perHour);
  String listPrice(double perHour);
  String get perHourShort;

  // Car
  String fuel(String type);
  String transmission(String type);
  String seats(int count);
  String reviewCount(int count);
  String get features;
  String get bookNow;
  String get perHour;
  String get perDay;
  String get reviews;

  // Booking
  String days(int count);
  String hours(double count);
  String get pickTimes;
  String get startInPast;
  String get endBeforeStart;
  String get logInFirst;
  String get requestSent;
  String get pickup;
  String get returnTime;
  String sendRequest(String price);
  String get chooseTime;
  String get ownerConfirms;
  String get choose;
  String get duration;
  String get total;
  String get platformFee;

  // Profile
  String get logOut;
  String get myBookings;
  String get noBookings;
  String get findCarOnMap;
  String status(String name);
  String get chat;
  String get rate;
  String get requestsAndRentals;
  String get noOpenRequests;
  String get confirmed;
  String get returnConfirmed;
  String get declined;
  String get decline;
  String get confirm;
  String get confirmReturn;
  String get myCars;
  String get listCar;
  String get account;
  String get verifyLicence;
  String get paymentMethods;

  // Listing
  String get locationDeniedSettings;
  String get setLocation;
  String get carListed;
  String get vehicle;
  String get make;
  String get model;
  String get year;
  String get invalid;
  String get plate;
  String get colourOptional;
  String get fuelLabel;
  String get gearbox;
  String get seatsLabel;
  String get prices;
  String get pricePerHourField;
  String get pricePerDayField;
  String get invalidPrice;
  String get location;
  String get addressOptional;
  String get positionSet;
  String get getGps;
  String get required;

  // Review
  String get review;
  String get howWasIt;
  String get commentOptional;
  String get submitReview;
  String get reviewSubmitted;

  // Chat
  String get noMessages;
  String get messageHint;
  String get send;
}

class De extends Messages {
  const De();

  @override
  String get madeBy => 'ein Werkzeug von';
  @override
  String get otherLanguage => 'English';

  @override
  String money(double amount, String currency) => currency == 'EUR'
      ? '${amount.toStringAsFixed(2).replaceAll('.', ',')} €'
      : '${amount.toStringAsFixed(2).replaceAll('.', ',')} $currency';
  @override
  String date(DateTime d) => '${_two(d.day)}.${_two(d.month)}.${d.year}';
  @override
  String dateTime(DateTime d) => '${date(d)}, ${_two(d.hour)}:${_two(d.minute)} Uhr';
  @override
  String error(Object e) => 'Fehler: $e';
  @override
  String rating(double value) => value.toStringAsFixed(1).replaceAll('.', ',');

  @override
  String get logIn => 'Anmelden';
  @override
  String get createAccount => 'Konto erstellen';
  @override
  String get email => 'E-Mail';
  @override
  String get password => 'Passwort';
  @override
  String get confirmEmail =>
      'Fast geschafft: Bitte bestätige deine E-Mail-Adresse über den Link, den wir dir geschickt haben.';
  @override
  String get signUp => 'Registrieren';
  @override
  String get or => 'oder';
  @override
  String get withApple => 'Mit Apple anmelden';
  @override
  String get withGoogle => 'Mit Google anmelden';
  @override
  String get haveAccount => 'Bereits ein Konto? Anmelden';
  @override
  String get noAccount => 'Noch kein Konto? Registrieren';

  @override
  String get locationOff => 'Die Ortungsdienste sind ausgeschaltet.';
  @override
  String get locationDenied => 'fahrbar hat keinen Zugriff auf deinen Standort.';
  @override
  String get locationUnavailable => 'Dein Standort ist gerade nicht verfügbar.';
  @override
  String showingFreiburg(String reason) => '$reason Du siehst Autos rund um Freiburg.';
  @override
  String get searchCar => 'Auto suchen…';
  @override
  String get findDriver => 'Fahrer finden…';
  @override
  String get profile => 'Profil';
  @override
  String get myLocation => 'Mein Standort';
  @override
  String get searchingCars => 'Suche Autos…';
  @override
  String get noCarsNearby => 'Keine Autos in der Nähe';
  @override
  String carsNearby(int count) => '$count ${count == 1 ? 'Auto' : 'Autos'} in der Nähe';
  @override
  String driversNearby(int count) => '$count Fahrer in der Nähe';
  @override
  String get tabCar => 'Auto';
  @override
  String get tabDriver => 'Fahrer';
  @override
  String get noCarFree => 'Im Umkreis von 10 km ist gerade kein Auto frei.';
  @override
  String markerPrice(double perHour) => '${perHour.toStringAsFixed(0)} €/h';
  @override
  String listPrice(double perHour) => '${perHour.toStringAsFixed(0)} €';
  @override
  String get perHourShort => '/Std';

  @override
  String fuel(String type) => switch (type) {
        'electric' => 'Elektro',
        'diesel' => 'Diesel',
        'hybrid' => 'Hybrid',
        _ => 'Benzin',
      };
  @override
  String transmission(String type) => type == 'automatic' ? 'Automatik' : 'Schaltung';
  @override
  String seats(int count) => '$count Sitze';
  @override
  String reviewCount(int count) => '($count ${count == 1 ? 'Bewertung' : 'Bewertungen'})';
  @override
  String get features => 'Ausstattung';
  @override
  String get bookNow => 'Jetzt buchen';
  @override
  String get perHour => 'pro Stunde';
  @override
  String get perDay => 'pro Tag';
  @override
  String get reviews => 'Bewertungen';

  @override
  String days(int count) => count == 1 ? '1 Tag' : '$count Tage';
  @override
  String hours(double count) => '${count.toStringAsFixed(1).replaceAll('.', ',')} Std.';
  @override
  String get pickTimes => 'Bitte Start- und Endzeit auswählen.';
  @override
  String get startInPast => 'Startzeit muss in der Zukunft liegen.';
  @override
  String get endBeforeStart => 'Endzeit muss nach Startzeit liegen.';
  @override
  String get logInFirst => 'Bitte zuerst anmelden.';
  @override
  String get requestSent => 'Anfrage gesendet. Der Vermieter muss noch bestätigen.';
  @override
  String get pickup => 'Abholung';
  @override
  String get returnTime => 'Rückgabe';
  @override
  String sendRequest(String price) => 'Anfrage senden · $price';
  @override
  String get chooseTime => 'Zeitraum auswählen';
  @override
  String get ownerConfirms => 'Der Vermieter bestätigt deine Anfrage';
  @override
  String get choose => 'Auswählen';
  @override
  String get duration => 'Dauer';
  @override
  String get total => 'Gesamtpreis';
  @override
  String get platformFee => 'davon Plattformgebühr (15 %)';

  @override
  String get logOut => 'Abmelden';
  @override
  String get myBookings => 'Meine Buchungen';
  @override
  String get noBookings => 'Noch keine Buchungen';
  @override
  String get findCarOnMap => 'Finde ein Auto auf der Karte';
  @override
  String status(String name) => switch (name) {
        'confirmed' => 'Bestätigt',
        'active' => 'Aktiv',
        'completed' => 'Abgeschlossen',
        'cancelled' => 'Storniert',
        'rejected' => 'Abgelehnt',
        'dispute' => 'Streitfall',
        _ => 'Ausstehend',
      };
  @override
  String get chat => 'Chat';
  @override
  String get rate => 'Bewerten';
  @override
  String get requestsAndRentals => 'Anfragen und Vermietungen';
  @override
  String get noOpenRequests => 'Keine offenen Anfragen';
  @override
  String get confirmed => 'Bestätigt!';
  @override
  String get returnConfirmed => 'Rückgabe bestätigt.';
  @override
  String get declined => 'Abgelehnt.';
  @override
  String get decline => 'Ablehnen';
  @override
  String get confirm => 'Bestätigen';
  @override
  String get confirmReturn => 'Rückgabe bestätigen';
  @override
  String get myCars => 'Meine Autos';
  @override
  String get listCar => 'Auto einstellen';
  @override
  String get account => 'Konto';
  @override
  String get verifyLicence => 'Führerschein verifizieren';
  @override
  String get paymentMethods => 'Zahlungsmethoden';

  @override
  String get locationDeniedSettings =>
      'fahrbar hat keinen Zugriff auf deinen Standort. Du kannst ihn in den Einstellungen erlauben.';
  @override
  String get setLocation => 'Bitte lege den Standort per GPS fest.';
  @override
  String get carListed => 'Auto erfolgreich eingestellt!';
  @override
  String get vehicle => 'Fahrzeug';
  @override
  String get make => 'Marke';
  @override
  String get model => 'Modell';
  @override
  String get year => 'Baujahr';
  @override
  String get invalid => 'Ungültig';
  @override
  String get plate => 'Kennzeichen';
  @override
  String get colourOptional => 'Farbe (optional)';
  @override
  String get fuelLabel => 'Kraftstoff';
  @override
  String get gearbox => 'Getriebe';
  @override
  String get seatsLabel => 'Sitzplätze';
  @override
  String get prices => 'Preise';
  @override
  String get pricePerHourField => 'Preis/Stunde (€)';
  @override
  String get pricePerDayField => 'Preis/Tag (€)';
  @override
  String get invalidPrice => 'Ungültiger Preis';
  @override
  String get location => 'Standort';
  @override
  String get addressOptional => 'Adresse (optional)';
  @override
  String get positionSet => 'Position gesetzt ✓';
  @override
  String get getGps => 'GPS-Position ermitteln';
  @override
  String get required => 'Pflichtfeld';

  @override
  String get review => 'Bewertung';
  @override
  String get howWasIt => 'Wie war deine Erfahrung?';
  @override
  String get commentOptional => 'Kommentar (optional)';
  @override
  String get submitReview => 'Bewertung abgeben';
  @override
  String get reviewSubmitted => 'Bewertung abgegeben!';

  @override
  String get noMessages => 'Noch keine Nachrichten.\nSchreib die erste!';
  @override
  String get messageHint => 'Nachricht …';
  @override
  String get send => 'Senden';
}

class En extends Messages {
  const En();

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  String get madeBy => 'a tool by';
  @override
  String get otherLanguage => 'Deutsch';

  @override
  String money(double amount, String currency) =>
      currency == 'EUR' ? '€${amount.toStringAsFixed(2)}' : '${amount.toStringAsFixed(2)} $currency';
  @override
  String date(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
  @override
  String dateTime(DateTime d) => '${date(d)}, ${_two(d.hour)}:${_two(d.minute)}';
  @override
  String error(Object e) => 'Error: $e';
  @override
  String rating(double value) => value.toStringAsFixed(1);

  @override
  String get logIn => 'Log in';
  @override
  String get createAccount => 'Create account';
  @override
  String get email => 'Email';
  @override
  String get password => 'Password';
  @override
  String get confirmEmail => 'Almost there: please confirm your email address with the link we sent you.';
  @override
  String get signUp => 'Sign up';
  @override
  String get or => 'or';
  @override
  String get withApple => 'Sign in with Apple';
  @override
  String get withGoogle => 'Sign in with Google';
  @override
  String get haveAccount => 'Already have an account? Log in';
  @override
  String get noAccount => 'No account yet? Sign up';

  @override
  String get locationOff => 'Location services are turned off.';
  @override
  String get locationDenied => "fahrbar can't access your location.";
  @override
  String get locationUnavailable => 'Your location is not available right now.';
  @override
  String showingFreiburg(String reason) => '$reason Showing cars around Freiburg.';
  @override
  String get searchCar => 'Search cars…';
  @override
  String get findDriver => 'Find drivers…';
  @override
  String get profile => 'Profile';
  @override
  String get myLocation => 'My location';
  @override
  String get searchingCars => 'Looking for cars…';
  @override
  String get noCarsNearby => 'No cars nearby';
  @override
  String carsNearby(int count) => '$count ${count == 1 ? 'car' : 'cars'} nearby';
  @override
  String driversNearby(int count) => '$count ${count == 1 ? 'driver' : 'drivers'} nearby';
  @override
  String get tabCar => 'Car';
  @override
  String get tabDriver => 'Driver';
  @override
  String get noCarFree => 'No car is free within 10 km right now.';
  @override
  String markerPrice(double perHour) => '€${perHour.toStringAsFixed(0)}/h';
  @override
  String listPrice(double perHour) => '€${perHour.toStringAsFixed(0)}';
  @override
  String get perHourShort => '/hr';

  @override
  String fuel(String type) => switch (type) {
        'electric' => 'Electric',
        'diesel' => 'Diesel',
        'hybrid' => 'Hybrid',
        _ => 'Petrol',
      };
  @override
  String transmission(String type) => type == 'automatic' ? 'Automatic' : 'Manual';
  @override
  String seats(int count) => '$count seats';
  @override
  String reviewCount(int count) => '($count ${count == 1 ? 'review' : 'reviews'})';
  @override
  String get features => 'Features';
  @override
  String get bookNow => 'Book now';
  @override
  String get perHour => 'per hour';
  @override
  String get perDay => 'per day';
  @override
  String get reviews => 'Reviews';

  @override
  String days(int count) => count == 1 ? '1 day' : '$count days';
  @override
  String hours(double count) => '${count.toStringAsFixed(1)} h';
  @override
  String get pickTimes => 'Please choose a start and end time.';
  @override
  String get startInPast => 'The start time must be in the future.';
  @override
  String get endBeforeStart => 'The end time must be after the start time.';
  @override
  String get logInFirst => 'Please log in first.';
  @override
  String get requestSent => 'Request sent. The owner still has to confirm.';
  @override
  String get pickup => 'Pick-up';
  @override
  String get returnTime => 'Return';
  @override
  String sendRequest(String price) => 'Send request · $price';
  @override
  String get chooseTime => 'Choose a time';
  @override
  String get ownerConfirms => 'The owner confirms your request';
  @override
  String get choose => 'Choose';
  @override
  String get duration => 'Duration';
  @override
  String get total => 'Total';
  @override
  String get platformFee => 'incl. platform fee (15%)';

  @override
  String get logOut => 'Log out';
  @override
  String get myBookings => 'My bookings';
  @override
  String get noBookings => 'No bookings yet';
  @override
  String get findCarOnMap => 'Find a car on the map';
  @override
  String status(String name) => switch (name) {
        'confirmed' => 'Confirmed',
        'active' => 'Active',
        'completed' => 'Completed',
        'cancelled' => 'Cancelled',
        'rejected' => 'Declined',
        'dispute' => 'Dispute',
        _ => 'Pending',
      };
  @override
  String get chat => 'Chat';
  @override
  String get rate => 'Rate';
  @override
  String get requestsAndRentals => 'Requests and rentals';
  @override
  String get noOpenRequests => 'No open requests';
  @override
  String get confirmed => 'Confirmed!';
  @override
  String get returnConfirmed => 'Return confirmed.';
  @override
  String get declined => 'Declined.';
  @override
  String get decline => 'Decline';
  @override
  String get confirm => 'Confirm';
  @override
  String get confirmReturn => 'Confirm return';
  @override
  String get myCars => 'My cars';
  @override
  String get listCar => 'List a car';
  @override
  String get account => 'Account';
  @override
  String get verifyLicence => "Verify driver's licence";
  @override
  String get paymentMethods => 'Payment methods';

  @override
  String get locationDeniedSettings => "fahrbar can't access your location. You can allow it in the settings.";
  @override
  String get setLocation => 'Please set the location via GPS.';
  @override
  String get carListed => 'Car listed!';
  @override
  String get vehicle => 'Vehicle';
  @override
  String get make => 'Make';
  @override
  String get model => 'Model';
  @override
  String get year => 'Year';
  @override
  String get invalid => 'Invalid';
  @override
  String get plate => 'Licence plate';
  @override
  String get colourOptional => 'Colour (optional)';
  @override
  String get fuelLabel => 'Fuel';
  @override
  String get gearbox => 'Transmission';
  @override
  String get seatsLabel => 'Seats';
  @override
  String get prices => 'Prices';
  @override
  String get pricePerHourField => 'Price per hour (€)';
  @override
  String get pricePerDayField => 'Price per day (€)';
  @override
  String get invalidPrice => 'Invalid price';
  @override
  String get location => 'Location';
  @override
  String get addressOptional => 'Address (optional)';
  @override
  String get positionSet => 'Position set ✓';
  @override
  String get getGps => 'Get GPS position';
  @override
  String get required => 'Required';

  @override
  String get review => 'Review';
  @override
  String get howWasIt => 'How was your experience?';
  @override
  String get commentOptional => 'Comment (optional)';
  @override
  String get submitReview => 'Submit review';
  @override
  String get reviewSubmitted => 'Review submitted!';

  @override
  String get noMessages => 'No messages yet.\nWrite the first one!';
  @override
  String get messageHint => 'Message…';
  @override
  String get send => 'Send';
}
