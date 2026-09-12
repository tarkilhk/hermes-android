import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/models/session_control.dart';

void main() {
  Map<String, dynamic> goal({
    String status = 'active',
    dynamic barrier,
    dynamic verdict,
  }) => {
    'title': 'Ship D24',
    'status': status,
    'turns_used': 2,
    'max_turns': 8,
    'contract': <String, dynamic>{
      'outcome': 'A useful release',
      'verification': 'Run the checks',
      'constraints': 'Keep scope bounded',
      'boundaries': 'No unrelated changes',
      'stop_when': 'Checks pass',
    },
    'subgoals': ['Implement model', 'Review details'],
    'gates': [
      {
        'command': 'flutter analyze',
        'timeout_seconds': 30,
        'max_retries': 1,
        'attempts': 0,
        'last_exit_code': null,
      },
    ],
    'wait_barrier': ?barrier,
    'last_verdict': ?verdict,
  };

  test('parses full server control response and typed details', () {
    final snapshot = SessionControlSnapshot.parse({
      'control': {
        'goal': goal(
          status: 'paused',
          verdict: 'wait',
          barrier: {
            'type': 'session',
            'target': 'other-session',
            'reason': 'Waiting for dependency',
          },
        ),
        'revision': 'opaque-sha',
        'updated_at': 123.5,
      },
    });

    expect(snapshot, isNotNull);
    expect(snapshot!.revision, 'opaque-sha');
    expect(snapshot.goal!.status, SessionGoalStatus.paused);
    expect(snapshot.goal!.contract.verification, 'Run the checks');
    expect(snapshot.goal!.subgoals, ['Implement model', 'Review details']);
    expect(snapshot.goal!.gates.single.command, 'flutter analyze');
    expect(snapshot.goal!.waitBarrier!.sessionTarget, 'other-session');
    expect(snapshot.goal!.lastVerdict, SessionGoalVerdict.wait);
  });

  test('accepts a valid empty goal snapshot', () {
    final snapshot = SessionControlSnapshot.parse({
      'control': {'goal': null, 'revision': '', 'updated_at': 0},
    });
    expect(snapshot, isNotNull);
    expect(snapshot!.goal, isNull);
  });

  test('keeps additive server fields instead of hiding the goal', () {
    final value = goal()..['future_field'] = {'new': true};
    (value['contract'] as Map<String, dynamic>)['future_contract_field'] = 1;
    final snapshot = SessionControlSnapshot.parse({
      'control': {'goal': value, 'revision': 'r', 'updated_at': 0},
    });
    expect(snapshot!.goal!.title, 'Ship D24');
  });

  test('rejects malformed snapshots and unsupported barrier fields', () {
    expect(
      SessionControlSnapshot.parse({
        'control': {
          'goal': goal(status: 'running'),
          'revision': 'r',
          'updated_at': 1,
        },
      }),
      isNull,
    );
    expect(
      SessionControlSnapshot.parse({
        'control': {
          'goal': goal(barrier: {'type': 'pid', 'target': '42', 'reason': 'x'}),
          'revision': 'r',
          'updated_at': 1,
        },
      }),
      isNull,
    );
    expect(
      SessionControlSnapshot.parse({
        'control': {'goal': null},
      }),
      isNull,
    );
    expect(
      SessionControlSnapshot.parse({
        'control': {'revision': 'r', 'updated_at': 1},
      }),
      isNull,
    );
  });
}
