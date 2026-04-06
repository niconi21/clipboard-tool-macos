import Foundation

extension UserDefaults {
    var onboardingCompleted: Bool {
        get { bool(forKey: "onboardingCompleted") }
        set { set(newValue, forKey: "onboardingCompleted") }
    }
}
