// CM-053: pull_request CI runs must never see release secrets, must still
// exercise the release build with a throwaway keystore, must keep those
// artifacts out of the publish path, and must delete signing files at job end.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

final _gatedSecret = RegExp(
  r"^\$\{\{ github\.event_name != 'pull_request' && secrets\.(\w+) \|\| '' \}\}$",
);

const _releaseSecrets = {
  'KEYSTORE_BASE64',
  'KEYSTORE_STORE_PASSWORD',
  'KEYSTORE_KEY_PASSWORD',
  'KEYSTORE_KEY_ALIAS',
  'SENTRY_DSN',
  'FEEDBACK_HMAC_SECRET',
  'SENTRY_AUTH_TOKEN',
};

Iterable<String> _strings(Object? node) sync* {
  if (node is String) {
    yield node;
  } else if (node is Map) {
    for (final value in node.values) {
      yield* _strings(value);
    }
  } else if (node is List) {
    for (final value in node) {
      yield* _strings(value);
    }
  }
}

void main() {
  final workflow =
      loadYaml(File('.github/workflows/ci.yml').readAsStringSync()) as YamlMap;
  final jobs = workflow['jobs'] as YamlMap;
  final release = jobs['release'] as YamlMap;
  final steps = (release['steps'] as YamlList).cast<YamlMap>();

  YamlMap step(String name) => steps.singleWhere((s) => s['name'] == name);

  YamlMap upload(String artifact) => steps.singleWhere(
        (s) =>
            s['with'] is YamlMap && (s['with'] as YamlMap)['name'] == artifact,
      );

  test('the workflow runs on pull_request', () {
    expect((workflow['on'] as YamlMap).containsKey('pull_request'), isTrue);
  });

  test('every secret the release job reads is blanked on pull_request', () {
    final referenced = <String>{};
    for (final value in _strings(release)) {
      if (!value.contains('secrets.')) continue;
      final match = _gatedSecret.firstMatch(value.trim());
      expect(match, isNotNull, reason: 'ungated secret reference: $value');
      referenced.add(match!.group(1)!);
    }
    expect(referenced, _releaseSecrets);
  });

  test(
      'jobs outside release that read secrets only run on real-keystore pushes',
      () {
    for (final MapEntry(:key, :value) in jobs.entries) {
      if (key == 'release') continue;
      if (!_strings(value).any((s) => s.contains('secrets.'))) continue;
      final condition = (value as YamlMap)['if'] as String?;
      expect(condition, contains("needs.release.outputs.used_real == 'yes'"),
          reason: '$key');
      expect(condition, contains("github.event_name == 'push'"),
          reason: '$key');
    }
  });

  test('without a real keystore a one-day throwaway keystore signs the build',
      () {
    final run = step('Resolve signing keystore')['run'] as String;
    expect(run, contains('if [ "\$USED_REAL" = "no" ]; then'));
    expect(run, contains('-validity 1'));
    expect(run, contains('-storetype PKCS12'));
    expect(run, contains('> android/key.properties'));
    expect(run, contains(r'echo "used_real=$USED_REAL" >> "$GITHUB_OUTPUT"'));
    expect(release['outputs']['used_real'],
        r'${{ steps.keystore.outputs.used_real }}');

    for (final build in ['Build release AAB', 'Build release APK']) {
      expect(step(build).containsKey('if'), isFalse, reason: build);
    }
  });

  test('publishable artifacts require the real keystore', () {
    for (final artifact in ['release-aab', 'release-apk', 'release-mapping']) {
      expect(
          upload(artifact)['if'], "steps.keystore.outputs.used_real == 'yes'",
          reason: artifact);
    }
  });

  test('throwaway-signed artifacts are uploaded under non-publishable names',
      () {
    for (final artifact in [
      'release-aab-ci-throwaway',
      'release-apk-ci-throwaway',
    ]) {
      final s = upload(artifact);
      expect(s['if'], "steps.keystore.outputs.used_real != 'yes'",
          reason: artifact);
      expect(s['with']['retention-days'], 7, reason: artifact);
    }
  });

  test('signing credentials are deleted whatever the job outcome', () {
    final cleanup = step('Clean up signing credentials');
    expect(cleanup['if'], 'always()');
    expect(cleanup['run'], contains('android/cosmic-match-release.jks'));
    expect(cleanup['run'], contains('android/key.properties'));
    expect(cleanup['run'], startsWith('rm -f '));
  });
}
