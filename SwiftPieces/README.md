# SwiftPieces adaptation

`Controls/ElasticButton.swift` is a focused macOS adaptation of [SwiftPieces ElasticButton](https://swiftpieces.com/docs/components/controls/elastic-button) by Saivion Hayes, retrieved through the SwiftPieces integration on 2 November 2026.

It retains the original 0.96 press scale and the tight and elastic spring values. The adapter uses a native SwiftUI primitive button style, leaving activation, labels, keyboard behaviour and focus to the wrapped system button. It applies to the foundation window's Open App Settings link. Feature toggles, sliders, the native menu and the separate General Settings form keep their standard control styling.

Native Liquid Glass buttons are available on macOS 26 and later. Earlier systems and Reduce Transparency use native bordered buttons. Reduce Motion removes the additional press scale and spring. The iOS component's touch-point deformation, hold tasks, palette, UIKit colour adapters and haptics are omitted from this macOS adaptation. Notch interaction and its existing haptics remain independent.

This component is covered by [LICENSE.txt](LICENSE.txt), including its Commons Clause restriction. That licence applies to this adaptation separately from the repository's MIT licence. Xcode copies the notice into the application bundle. SwiftLint and SwiftFormat include the adapter.
