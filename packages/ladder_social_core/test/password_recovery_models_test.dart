import 'package:flutter_test/flutter_test.dart';
import 'package:ladder_social_core/ladder_social_core.dart';

void main() {
  test('OperationMessage parses the generic recovery response', () {
    final OperationMessage message = OperationMessage.fromJson(
      <String, dynamic>{
        'message':
            'If an active account exists for that email address, a reset code has been sent.',
      },
    );

    expect(message.message, contains('reset code has been sent'));
  });

  test('reference-data models parse database identifiers', () {
    final CityItem city = CityItem.fromJson(<String, dynamic>{
      'id': '7ad1997e-c9d4-4f33-bd30-c759cb3532f8',
      'name': 'Mostar',
      'countryId': 'e6158e99-f176-438c-aa06-d5bd6e783df8',
      'countryName': 'Bosnia and Herzegovina',
    });

    expect(city.name, 'Mostar');
    expect(city.countryName, 'Bosnia and Herzegovina');
  });
}
