import 'package:ladder_social_core/src/auth/auth_models.dart';

final class ReferenceItem {
  const ReferenceItem({
    required this.id,
    required this.code,
    required this.name,
  });

  factory ReferenceItem.fromJson(Map<String, dynamic> json) => ReferenceItem(
        id: requiredString(json, 'id'),
        code: requiredString(json, 'code'),
        name: requiredString(json, 'name'),
      );

  final String id;
  final String code;
  final String name;
}

final class CountryItem {
  const CountryItem({
    required this.id,
    required this.isoCode,
    required this.name,
  });

  factory CountryItem.fromJson(Map<String, dynamic> json) => CountryItem(
        id: requiredString(json, 'id'),
        isoCode: requiredString(json, 'isoCode'),
        name: requiredString(json, 'name'),
      );

  final String id;
  final String isoCode;
  final String name;
}

final class CityItem {
  const CityItem({
    required this.id,
    required this.name,
    required this.countryId,
    required this.countryName,
  });

  factory CityItem.fromJson(Map<String, dynamic> json) => CityItem(
        id: requiredString(json, 'id'),
        name: requiredString(json, 'name'),
        countryId: requiredString(json, 'countryId'),
        countryName: requiredString(json, 'countryName'),
      );

  final String id;
  final String name;
  final String countryId;
  final String countryName;
}
