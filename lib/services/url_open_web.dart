import 'package:web/web.dart' as web;

/// Opens [url] in a new browser tab.
void openUrl(String url) {
  web.window.open(url, '_blank');
}

/// Navigates to a hash route (e.g. '/ticket') with a full reload so the
/// app restarts with the new initial route. Used from the lock screen,
/// where the app Navigator is not mounted yet.
void gotoHashRoute(String route) {
  web.window.location.hash = route;
  web.window.location.reload();
}
