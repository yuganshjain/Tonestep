import Foundation

/// External URLs the app links to.
///
/// Centralised because App Store review rejects an app whose privacy policy URL
/// does not load, and these were previously hardcoded at the call site pointing
/// at a host that does not serve them.
enum AppLinks {
    /// GitHub Pages, served from the repository's docs/ directory.
    /// The path segment is the repository name, so renaming the repo changes this
    /// URL. App Store review rejects an app whose privacy policy fails to load,
    /// so re-verify this link after any repository rename.
    private static let siteRoot = "https://yuganshjain.github.io/Tonestep"

    static let privacyPolicy = URL(string: "\(siteRoot)/privacy.html")!
    static let supportSite = URL(string: "\(siteRoot)/")!
}
