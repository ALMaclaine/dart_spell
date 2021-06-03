library dart_spell;

import 'dart:collection';

import 'package:spell_checker/utilities.dart';


///
/// Simple dictionary based spell checker.
///
class SingleWordSpellChecker {
  final bool checkNearKeySubstitution = false;

  final double INSERTION_PENALTY = 0.4;
  final double DELETION_PENALTY = 0.6;
  final double SUBSTITUTION_PENALTY = 0.6;
  final double TRANSPOSITION_PENALTY = 0.6;

  //TODO: not used yet.
  final double NEAR_KEY_SUBSTITUTION_PENALTY = 0.5;
  final Map<int, String> nearKeyMap = <int, String>{};
  SplayTreeMap<String, double> hypotheses;

  double distance;
  _Node _root;

  SingleWordSpellChecker({num distance = 1}) {
    if (distance != null) this.distance = distance;
    _root = _Node(0);
  }

  void addWord(String word) => _addChar(word, word);

  void addWords(Iterable<String> words) => words?.forEach(addWord);

  void _addChar(String word, String actual) {
    var tmpNode = _root;
    for (final rune in word?.toLowerCase()?.runes) {
      // TODO: Add tests for this
      // TODO: Make custom exception
      if (!isChar(rune)) {
        throw Exception(
            'Invalid character added to spell checker, code unit: $rune}');
      }
      tmpNode = tmpNode?.addChild(rune);
    }
    tmpNode.word = actual;
  }

  bool isWord(String input) {
    var tmpNode = _root;
    for (final rune in input.runes) {
      if (tmpNode.hasChild(rune)) {
        tmpNode = tmpNode.getChild(rune);
      } else {
        return false;
      }
    }
    return tmpNode.endsWord;
  }

  List<Result> find(String input) {
    if (isWord(input)) return [Result(input, 0)];
    final lowered = input.toLowerCase();
    hypotheses = SplayTreeMap<String, double>();

    final hyp = _Hypothesis(_root, 0.0, -1);
    var next = _expand(hyp, lowered);
    while (next.isNotEmpty) {
      final expanded = next.map((hyp) => _expand(hyp, lowered));
      next = expanded.reduce((e, v) => v?.union(e));
    }

    return hypotheses.keys.map((key) => Result(key, hypotheses[key])).toList();
  }

  Set<_Hypothesis> _noError(_Hypothesis hypothesis, String input) {
    final nextIndex = hypothesis.index + 1;
    final hypNode = hypothesis.node;
    final newHypotheses = <_Hypothesis>{};

    if (nextIndex < input.length) {
      if (hypNode.hasChild(input.codeUnitAt(nextIndex))) {
        final hyp = hypothesis.getNewMoveForward(
            hypNode.getChild(input.codeUnitAt(nextIndex)), 0.0);
        newHypotheses.add(hyp);
      }
    } else {
      if (hypothesis.isWord) {
        _addHypothesis(hypothesis);
      }
    }
    return newHypotheses;
  }



Set<_Hypothesis> _handleNearKey(
      _Hypothesis hypothesis, String input, _Node childNode) {
    final nextIndex = hypothesis.index + 1;
    final newHypotheses = <_Hypothesis>{};

    final nextChar = input.codeUnitAt(nextIndex);
    if (childNode.chr != nextChar) {
      final nearCharactersString = nearKeyMap[childNode.chr];
      if (nearCharactersString != null &&
          nearCharactersString.runes.contains(nextChar)) {
        //NEAR_KEY_SUBSTITUTION_PENALTY;
      }
    }

    return newHypotheses;
  }

  Set<_Hypothesis> _handleSubstitution(
      _Hypothesis hypothesis, String input, _Node childNode) {
    final nextIndex = hypothesis.index + 1;
    final hypDist = hypothesis.distance;
    final newHypotheses = <_Hypothesis>{};

    if (hypDist + SUBSTITUTION_PENALTY <= distance) {
      // TODO consider double add for noError
      final hyp = hypothesis.getNewMoveForward(childNode, SUBSTITUTION_PENALTY);
      if (nextIndex == input.length - 1) {
        if (hyp.isWord) {
          _addHypothesis(hyp);
        }
      } else {
        newHypotheses.add(hyp);
      }
    }

    return newHypotheses;
  }

  Set<_Hypothesis> _substitution(_Hypothesis hypothesis, String input) {
    final nextIndex = hypothesis.index + 1;
    final children = hypothesis.node.children;
    final newHypotheses = <_Hypothesis>{};

    // substitution
    if (nextIndex < input.length) {
      for (final childNode in children) {
        if (checkNearKeySubstitution) {
          newHypotheses.addAll(_handleNearKey(hypothesis, input, childNode));
        } else {
          newHypotheses
              .addAll(_handleSubstitution(hypothesis, input, childNode));
        }
      }
    }
    return newHypotheses;
  }

  Set<_Hypothesis> _deletion(_Hypothesis hypothesis, String input) {
    final hypNode = hypothesis.node;
    final newHypotheses = <_Hypothesis>{};

    newHypotheses.add(hypothesis.getNewMoveForward(hypNode, DELETION_PENALTY));
    return newHypotheses;
  }

  Set<_Hypothesis> _insertion(_Hypothesis hypothesis, String input) {
    final hypNode = hypothesis.node;
    final newHypotheses = <_Hypothesis>{};

    // insertion
    for (final childNode in hypNode.children) {
      newHypotheses.add(
          hypothesis.getNew(childNode, INSERTION_PENALTY, hypothesis.index));
    }

    return newHypotheses;
  }

  Set<_Hypothesis> _transposition(_Hypothesis hypothesis, String input) {
    final hypNode = hypothesis.node;
    final nextIndex = hypothesis.index + 1;
    final newHypotheses = <_Hypothesis>{};

    if (nextIndex < input.length - 1) {
      final transpose = input.codeUnitAt(nextIndex + 1);
      final nextNode = hypNode.getChild(transpose);
      final nextChar = input.codeUnitAt(nextIndex);
      if (hypNode.hasChild(transpose) && nextNode.hasChild(nextChar)) {
        final hyp = hypothesis.getNew(
            nextNode.getChild(nextChar), TRANSPOSITION_PENALTY, nextIndex + 1);
        if (nextIndex == input.length - 1) {
          if (hyp.isWord) {
            _addHypothesis(hyp);
          }
        } else {
          newHypotheses.add(hyp);
        }
      }
    }
    return newHypotheses;
  }

  Set<_Hypothesis> _expand(_Hypothesis hypothesis, String input) {
    final newHypotheses = <_Hypothesis>{};
    final hypDist = hypothesis.distance;

    // no-error
    newHypotheses.addAll(_noError(hypothesis, input));

    // we don't need to explore further if we reached to max penalty
    if (hypDist >= distance) {
      return newHypotheses;
    } else {
      newHypotheses.addAll(_substitution(hypothesis, input));
    }

    if (hypDist + DELETION_PENALTY > distance) {
      return newHypotheses;
    } else {
      newHypotheses.addAll(_deletion(hypothesis, input));
    }

    newHypotheses.addAll(_insertion(hypothesis, input));

    // transposition
    newHypotheses.addAll(_transposition(hypothesis, input));

    return newHypotheses;
  }

  void _addHypothesis(_Hypothesis hypToAdd) {
    final hypWord = hypToAdd.node.word;
    if (isNull(hypWord)) return;
    if (hypotheses.containsKey(hypWord)) {
      if (hypToAdd.distance < hypotheses[hypWord]) {
        hypotheses.update(hypWord, (val) => hypToAdd.distance);
      }
    } else {
      hypotheses.putIfAbsent(hypWord, () => hypToAdd.distance);
    }
  }
}

class _Node {
  final int chr;
  final Map<int, _Node> nodes = <int, _Node>{};

  String _word;

  set word(String word) => _word = word ?? _word;

  String get word => _word;

  _Node(this.chr);

  Iterable<_Node> get children => nodes.values;

  bool hasChild(int c) => nodes.containsKey(c);

  _Node getChild(int c) => nodes[c];

  _Node addChild(int c) => nodes.putIfAbsent(c, () => _Node(c));

  bool get endsWord => !isNull(_word);

  @override
  int get hashCode {
    return chr;
  }
}

/// Hypothesis: That the node held in this string ends a word that could be a correct spelling
class _Hypothesis {
  final _Node node;
  final double distance;
  final int index;

  const _Hypothesis(this.node, this.distance, this.index);

  const _Hypothesis.initialNode(this.node, this.distance) : index = -1;

  //  _Hypothesis
  _Hypothesis getNewMoveForward(_Node node, double penaltyToAdd) {
    return _Hypothesis(node, distance + penaltyToAdd, index + 1);
  }

  _Hypothesis getNew(_Node node, double penaltyToAdd, int index) {
    return _Hypothesis(node, distance + penaltyToAdd, index);
  }

  bool get isWord => node.endsWord;

  @override
  int get hashCode {
    var result = node.hashCode;
    result = result * 31 + distance.hashCode;
    result = result * 31 + index;
    return result;
  }

  @override
  bool operator ==(other) {
    if (other is! _Hypothesis) return false;
    return index == other.index &&
        distance.compareTo(other.distance) == 0 &&
        node == other.node;
  }
}

/// Result value
class Result implements Comparable<Result> {
  final String word;
  final double distance;

  const Result(this.word, this.distance);

  @override
  int compareTo(Result other) => distance.compareTo(other.distance);

  @override
  String toString() => '$word:$distance';
}
