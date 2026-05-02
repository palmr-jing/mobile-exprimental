import SwiftUI

struct ModeSwitcher: View {
    @EnvironmentObject var authService: AuthService
    @AppStorage("appMode") private var appMode: AppMode = .developer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(AppMode.allCases, id: \.self) { mode in
                    let isDisabled = mode == .developer && !authService.isAdmin

                    Button {
                        if !isDisabled {
                            appMode = mode
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: DS.Spacing.md) {
                            Image(systemName: mode.icon)
                                .font(.title2)
                                .foregroundStyle(appMode == mode ? DS.Colors.accent : DS.Colors.secondary)
                                .frame(width: 40)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.displayName)
                                    .font(DS.Typography.subheading)
                                    .foregroundStyle(isDisabled ? DS.Colors.secondary : DS.Colors.text)
                                Text(mode.description)
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(DS.Colors.secondary)
                                if isDisabled {
                                    Text("Admin access required")
                                        .font(DS.Typography.small)
                                        .foregroundStyle(DS.Colors.red)
                                }
                            }

                            Spacer()

                            if appMode == mode {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(DS.Colors.accent)
                            }
                        }
                        .padding(.vertical, DS.Spacing.xs)
                    }
                    .disabled(isDisabled)
                }
            }
            .navigationTitle("Switch Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
