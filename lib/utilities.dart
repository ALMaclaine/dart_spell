import 'package:spell_checker/constants.dart';

/// Determines whether parameter is null
bool isNull(Object obj) {
  return obj == null;
}

/// Determines whether parameter is a character
bool isChar(int char) {
  return !isNull(char) &&
      char >= CHARACTER_RANGE_LOW &&
      char <= CHARACTER_RANGE_HIGH;
}