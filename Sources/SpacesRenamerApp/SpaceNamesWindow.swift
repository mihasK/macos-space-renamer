import SpacesRenamerCore
import SwiftUI

struct SpaceNamesWindow: View {
    @ObservedObject var viewModel: SpaceNamesViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(viewModel.spaces) { space in
                        SpaceNameRow(
                            space: space,
                            name: viewModel.binding(for: space)
                        )
                    }
                }
                .padding(.vertical, 2)
            }

            HStack {
                Button("Refresh") {
                    viewModel.reload()
                }

                Spacer()

                Button("Done") {
                    viewModel.close()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .frame(width: 420, height: 460)
        .padding(20)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Desktop Names")
                .font(.title2.weight(.semibold))

            Text("Names are stored locally and shown in the menu bar.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SpaceNameRow: View {
    let space: DesktopSpace
    @Binding var name: String

    var body: some View {
        HStack(spacing: 12) {
            Text(space.defaultTitle)
                .font(.body.monospacedDigit())
                .foregroundStyle(space.isCurrent ? .primary : .secondary)
                .frame(width: 92, alignment: .leading)

            TextField(space.defaultTitle, text: $name)
                .textFieldStyle(.roundedBorder)
        }
    }
}
