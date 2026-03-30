import AppKit
import ApplicationServices
import SwiftUI

// MARK: - ViewModel

@Observable
final class OnboardingViewModel {
    var currentStep: Int = 0
    var accessibilityGranted: Bool = AXIsProcessTrusted()

    static let totalSteps = 3

    func checkAccessibility() {
        accessibilityGranted = AXIsProcessTrusted()
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    func complete() {
        UserDefaults.standard.set(true, forKey: "onboardingCompleted")
    }
}

// MARK: - Root view

struct OnboardingView: View {
    @State private var viewModel = OnboardingViewModel()
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Step indicators
            StepIndicatorView(
                totalSteps: OnboardingViewModel.totalSteps,
                currentStep: viewModel.currentStep
            )
            .padding(.top, Spacing.xl)

            // Page content
            Group {
                switch viewModel.currentStep {
                case 0:
                    WelcomeStepView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                case 1:
                    AccessibilityStepView(viewModel: viewModel)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                default:
                    ReadyStepView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(Animations.popover, value: viewModel.currentStep)

            Divider()

            // Navigation buttons
            NavigationBarView(viewModel: viewModel, onDismiss: onDismiss)
                .padding(Spacing.xl)
        }
        .frame(width: 480, height: 400)
        .background(.regularMaterial)
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
        ) { _ in
            viewModel.checkAccessibility()
        }
    }
}

// MARK: - Step indicators

private struct StepIndicatorView: View {
    let totalSteps: Int
    let currentStep: Int

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index == currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: index == currentStep ? 20 : 8, height: 8)
                    .animation(Animations.popover, value: currentStep)
            }
        }
        .padding(.bottom, Spacing.md)
    }
}

// MARK: - Navigation bar

private struct NavigationBarView: View {
    var viewModel: OnboardingViewModel
    var onDismiss: () -> Void

    private var isLastStep: Bool {
        viewModel.currentStep == OnboardingViewModel.totalSteps - 1
    }

    var body: some View {
        HStack {
            // Back button
            if viewModel.currentStep > 0 {
                Button {
                    withAnimation(Animations.popover) {
                        viewModel.currentStep -= 1
                    }
                } label: {
                    Text(String(localized: "Back"))
                        .frame(minWidth: 80, minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Next / Done button
            if isLastStep {
                Button {
                    viewModel.complete()
                    onDismiss()
                } label: {
                    Text(String(localized: "Start using ClipboardTool"))
                        .fontWeight(.semibold)
                        .frame(minHeight: 44)
                        .padding(.horizontal, Spacing.lg)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Button {
                    withAnimation(Animations.popover) {
                        viewModel.currentStep += 1
                    }
                } label: {
                    Text(String(localized: "Next"))
                        .fontWeight(.semibold)
                        .frame(minWidth: 80, minHeight: 44)
                        .padding(.horizontal, Spacing.sm)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }
}

// MARK: - Step 1: Welcome

private struct WelcomeStepView: View {
    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 56, weight: .regular))
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.bounce, value: true)

            VStack(spacing: Spacing.sm) {
                Text(String(localized: "ClipboardTool"))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)

                Text(String(localized: "Your clipboard, supercharged"))
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Text(String(localized: "Keep track of everything you copy. Search, browse, and paste your full clipboard history — without ever leaving the keyboard."))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(.horizontal, Spacing.xl)
    }
}

// MARK: - Step 2: Accessibility Permission

private struct AccessibilityStepView: View {
    var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 80, height: 80)

                Image(systemName: "keyboard")
                    .font(.system(size: 36, weight: .regular))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(spacing: Spacing.sm) {
                Text(String(localized: "Enable Global Hotkey"))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text(String(localized: "The global shortcut ⌘⇧V requires Accessibility access so ClipboardTool can respond to keyboard input from any app."))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Status row
            HStack(spacing: Spacing.sm) {
                if viewModel.accessibilityGranted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(.green)

                    Text(String(localized: "Accessibility access granted"))
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                } else {
                    Button {
                        viewModel.openAccessibilitySettings()
                    } label: {
                        Label(
                            String(localized: "Open System Settings"),
                            systemImage: "arrow.up.right.square"
                        )
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
            }

            Spacer()
        }
        .padding(.horizontal, Spacing.xl)
    }
}

// MARK: - Step 3: Ready

private struct ReadyStepView: View {
    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 80, height: 80)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44, weight: .regular))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: true)
            }

            VStack(spacing: Spacing.sm) {
                Text(String(localized: "You're all set!"))
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)

                Text(String(localized: "ClipboardTool is ready. Click the clipboard icon in the menu bar or press ⌘⇧V to open your history."))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal, Spacing.xl)
    }
}
