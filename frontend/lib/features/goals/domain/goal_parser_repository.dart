import 'parsed_goal.dart';

/// Turns a free-text goal description (e.g. "Run 5 km this month") into a
/// structured target/unit. Callers must fall back to a generic goal on
/// failure — creating a goal must never be blocked by the AI being down.
abstract class GoalParserRepository {
  Future<ParsedGoal> parse(String description);
}
