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

/// Navigates the current tab to [url] (full page navigation).
/// Used for the Google OAuth start endpoint, which must redirect
/// the same tab through accounts.google.com and back.
void gotoUrl(String url) {
  web.window.location.href = url;
}

/// Removes query parameters from the address bar without reloading
/// (keeps path and hash). Used to strip OAuth tokens after login.
void clearUrlQuery() {
  try {
    final loc = web.window.location;
    web.window.history.replaceState(null, '', '${loc.pathname}${loc.hash}');
  } catch (_) {}
}
