# Golden Tests

Golden tests render the game widget at a fixed 1080x2244 viewport and compare
pixel-by-pixel against committed PNG baselines in `test/golden/goldens/`.

## Regenerating goldens

After an intentional UI change, regenerate baselines on a machine running the
same Flutter SDK version as CI:

    flutter test --update-goldens test/golden/

Commit the updated PNG files alongside the code change.

## CI note

Goldens are OS- and font-rendering-dependent. Always regenerate on a machine
matching CI's Flutter version, or trigger a manual workflow dispatch that runs
`flutter test --update-goldens` in CI and commits the results.
