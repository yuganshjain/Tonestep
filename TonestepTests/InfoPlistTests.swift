import XCTest
@testable import Tonestep

/// Guards the app's Info.plist against silent omissions.
///
/// Singing Practice shipped crashing on launch of the microphone because
/// NSMicrophoneUsageDescription was declared as an INFOPLIST_KEY_* build
/// setting, which Xcode only merges when GENERATE_INFOPLIST_FILE is YES.
/// This target has an explicit Info.plist, so the key was silently dropped and
/// iOS terminated the app the moment it touched the mic. Nothing in the build
/// warns about this, so it needs a test.
final class InfoPlistTests: XCTestCase {

    private func value(_ key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }

    func test_microphone_usage_description_is_present() {
        let description = value("NSMicrophoneUsageDescription")
        XCTAssertNotNil(description, "iOS kills the app on mic access without this key")
        XCTAssertFalse(description?.isEmpty ?? true)
    }

    /// App Store review rejects boilerplate that does not explain the actual use.
    func test_microphone_description_explains_the_use() {
        let description = value("NSMicrophoneUsageDescription")?.lowercased() ?? ""
        XCTAssertTrue(description.contains("pitch") || description.contains("sing"),
                      "the description must say what the microphone is actually for")
        XCTAssertGreaterThan(description.count, 30, "too short to satisfy review")
    }

    func test_display_name_matches_the_product() {
        XCTAssertEqual(value("CFBundleDisplayName"), "Tonestep")
    }

    func test_bundle_identifier_is_the_shipping_one() {
        XCTAssertEqual(Bundle.main.bundleIdentifier, "com.yugansh.Tonestep")
    }

    /// Absent this key iOS letterboxes the app into a 320x480 canvas with black
    /// bars, which is how it shipped before.
    func test_launch_screen_key_is_present() {
        XCTAssertNotNil(Bundle.main.object(forInfoDictionaryKey: "UILaunchScreen"),
                        "without UILaunchScreen iOS runs the app letterboxed")
    }

    func test_version_is_set() {
        XCTAssertFalse((value("CFBundleShortVersionString") ?? "").isEmpty)
    }
}
