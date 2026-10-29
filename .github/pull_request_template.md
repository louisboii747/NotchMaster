## Summary

<!-- What changed, and why? Keep this focused on one small, reviewable change. -->

## Related issue

<!-- Link an issue if there is one (for example, Fixes #123). -->

## Verification

<!-- Tick what you ran. For documentation-only changes, explain why a build is unnecessary. -->

- [ ] Apple Silicon Debug build: `xcodebuild -project NotchMaster.xcodeproj -scheme NotchMaster -configuration Debug -destination 'platform=macOS,arch=arm64' build`
- [ ] Apple Silicon tests: `xcodebuild -project NotchMaster.xcodeproj -scheme NotchMaster -configuration Debug -destination 'platform=macOS,arch=arm64' test`
- [ ] Manual testing (describe the steps and results below)
- [ ] Not run / not applicable (explain below)

**Test notes:**

<!-- Include macOS version, hardware, relevant test results, and any limitations. Don't claim tests passed unless you ran them. -->

## Visual changes

<!-- For UI changes, attach before/after screenshots or a short recording. Otherwise write "Not applicable". -->

## Checklist

- [ ] The change is scoped and follows the existing App / Core / UI responsibilities.
- [ ] I updated relevant docs if behaviour, architecture, or plans changed.
- [ ] I checked keyboard access, VoiceOver, and reduced-motion behaviour where relevant.
- [ ] I have not included secrets, private user data, or local signing assets.
