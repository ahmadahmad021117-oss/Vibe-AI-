import SwiftUI

/// FAQ — collapsible Q&A list, rendered inside a sheet from Profile.
struct FAQView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var expanded: Set<Int> = []

    var body: some View {
        legalContainer(title: "Frequently asked questions", dismiss: dismiss) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                ForEach(Array(LegalContent.faq.enumerated()), id: \.offset) { index, qa in
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expanded.contains(index) },
                            set: { isOpen in
                                if isOpen { expanded.insert(index) } else { expanded.remove(index) }
                            }
                        )
                    ) {
                        Text(qa.answer)
                            .font(Theme.Typo.body)
                            .foregroundStyle(Theme.Palette.textMuted)
                            .padding(.top, Theme.Spacing.sm)
                    } label: {
                        Text(qa.question)
                            .font(Theme.Typo.bodyBold)
                            .foregroundStyle(Theme.Palette.text)
                            .multilineTextAlignment(.leading)
                    }
                    .tint(Theme.Palette.accent)
                    .padding(Theme.Spacing.md)
                    .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radii.lg))
                }
            }
        }
    }
}

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        legalContainer(title: "Privacy Policy", dismiss: dismiss) {
            Text(LegalContent.privacyPolicy)
                .font(Theme.Typo.body)
                .foregroundStyle(Theme.Palette.text)
                .lineSpacing(4)
                .textSelection(.enabled)
        }
    }
}

struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        legalContainer(title: "Terms of Service", dismiss: dismiss) {
            Text(LegalContent.termsOfService)
                .font(Theme.Typo.body)
                .foregroundStyle(Theme.Palette.text)
                .lineSpacing(4)
                .textSelection(.enabled)
        }
    }
}

/// Shared chrome — title bar + dismiss button + scroll container.
@ViewBuilder
private func legalContainer<Content: View>(
    title: String,
    dismiss: DismissAction,
    @ViewBuilder content: () -> Content
) -> some View {
    ZStack {
        Theme.Palette.bg.ignoresSafeArea()
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(Theme.Typo.h2)
                    .foregroundStyle(Theme.Palette.text)
                Spacer()
                Button {
                    Haptics.tapLight()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textMuted)
                        .frame(width: 36, height: 36)
                        .background(Theme.Palette.surface, in: Circle())
                }
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.sm)

            ScrollView(showsIndicators: false) {
                content()
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.xl)
            }
        }
    }
    .preferredColorScheme(.dark)
}
