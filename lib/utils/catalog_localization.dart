import 'package:flutter/widgets.dart';

import '../services/catalog_repository.dart';

String catalogName(
  BuildContext context,
  String? catalogId, {
  String fallback = '',
}) {
  final locale = Localizations.localeOf(context).languageCode;
  return CatalogRepository.instance.content(catalogId, locale)?.name ??
      fallback;
}

String catalogDescription(
  BuildContext context,
  String? catalogId, {
  String fallback = '',
}) {
  final locale = Localizations.localeOf(context).languageCode;
  return CatalogRepository.instance.content(catalogId, locale)?.description ??
      fallback;
}
