# Golden Tests

Golden (screenshot) tests compare rendered frames of the game widget against
committed PNG baselines. They catch layout regressions invisible to unit tests:
grid drift, score-bar misplacement, refill overshoot.

## Running goldens

```sh
flutter test test/golden/
```

## Regenerating baselines after an intentional UI change

Goldens are pixel-exact and OS-dependent (font rendering varies). Always
regenerate on a machine — or in CI — matching the pinned environment:

- **Flutter**: 3.41.0
- **OS**: ubuntu-latest (matches the CI `Test` job)

```sh
flutter test --update-goldens test/golden/
```

Commit the updated `test/golden/goldens/*.png` files alongside your code change.

## Regenerating via CI

Trigger the workflow manually with `--update-goldens` by adding a
`workflow_dispatch` job to `.github/workflows/ci.yml` that runs:

```sh
flutter test --update-goldens test/golden/
git add test/golden/goldens/
git commit -m "chore: regenerate golden baselines"
git push
```

Or update goldens locally on Ubuntu with Flutter 3.41.0 and push the PNG files.

## Baseline files

| File | Test |
|------|------|
| `goldens/fresh_board.png` | `fresh_board_test.dart` |
| `goldens/post_match_clear.png` | `post_match_clear_test.dart` |
| `goldens/post_refill.png` | `post_refill_test.dart` |
| `goldens/score_bar.png` | `score_bar_test.dart` |

## Acceptance proof

To verify goldens catch layout bugs: revert the camera-anchor fix from #40
(remove `camera.viewfinder.anchor = Anchor.topLeft;` from `match3_game.dart`)
and run `flutter test test/golden/`. All four golden tests should fail with a
pixel mismatch showing the grid shifted to the bottom-right quadrant.
