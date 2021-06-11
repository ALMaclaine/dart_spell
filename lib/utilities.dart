import 'package:spell_checker/constants.dart';

/// Determines whether parameter is a character
bool isChar(int? char) {
  return !(char==null) &&
      char >= CHARACTER_RANGE_LOW &&
      char <= CHARACTER_RANGE_HIGH;
}