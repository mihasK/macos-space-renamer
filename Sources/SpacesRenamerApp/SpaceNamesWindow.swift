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
                LazyVStack(alignment: .leading, spacing: 8) {
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
            Text("Spaces")
                .font(.title2.weight(.semibold))

            Text("Rename spaces locally. Use the panel number to switch.")
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
            Text(space.numberTitle)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(space.isCurrent ? .white : .primary)
                .frame(width: 28, height: 24)
                .background(space.isCurrent ? Color.accentColor : Color.secondary.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            TextField("Name this space", text: $name)
                .textFieldStyle(.roundedBorder)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(space.isCurrent ? Color.accentColor.opacity(0.12) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
