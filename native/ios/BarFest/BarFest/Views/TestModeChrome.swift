import SwiftUI

/// Cap-style Test Mode control strip (shown when DevTestMode UI is enabled).
struct TestModeChrome: View {
    @ObservedObject private var testMode = TestModeStore.shared

    var body: some View {
        if testMode.uiEnabled {
            HStack(spacing: 10) {
                Button {
                    testMode.useMockCheckIns.toggle()
                    DiagnosticLog.shared.append(
                        category: "system",
                        message: "Test Mode mock=\(testMode.useMockCheckIns)"
                    )
                } label: {
                    Text("Test Mode")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(testMode.useMockCheckIns ? Color.blue : Color.clear)
                        .foregroundStyle(testMode.useMockCheckIns ? .white : .primary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.primary, lineWidth: 2)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Text(testMode.useMockCheckIns ? "Mock data on" : "Live data")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(.bar)
        }
    }
}
