import 'package:flutter/foundation.dart';

enum FriendsSection {
  friends,
  requests,
  discover,
}

/// Coordinates relationship changes that originate outside the Friends tab,
/// such as accepting a request from people search.
final class FriendsScreenController extends ChangeNotifier {
  int _revision = 0;
  FriendsSection? _requestedSection;

  int get revision => _revision;

  void refresh({FriendsSection? section}) {
    _requestedSection = section;
    _revision++;
    notifyListeners();
  }

  FriendsSection? takeRequestedSection() {
    final FriendsSection? section = _requestedSection;
    _requestedSection = null;
    return section;
  }
}
