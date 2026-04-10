import SwiftUI

struct CollectionEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State var name: String
    @State var symbol: String
    @State var color: Color

    let title: String
    let onSave: (String, String, String) -> Void

    private let commonSymbols = [
        "folder.fill", "star.fill", "heart.fill", "bookmark.fill",
        "tag.fill", "flag.fill", "bolt.fill", "flame.fill",
        "leaf.fill", "drop.fill", "cloud.fill", "sun.max.fill",
        "moon.fill", "sparkles", "globe", "building.2.fill",
        "briefcase.fill", "cart.fill", "gift.fill", "phone.fill",
        "envelope.fill", "bubble.left.fill", "person.fill", "person.2.fill",
        "hand.thumbsup.fill", "lightbulb.fill", "gearshape.fill", "wrench.fill",
        "paintbrush.fill", "pencil", "scissors", "doc.fill",
        "photo.fill", "camera.fill", "music.note", "play.fill",
        "gamecontroller.fill", "airplane", "car.fill", "tram.fill",
    ]

    init(title: String = "New Collection", name: String = "", symbol: String = "folder.fill",
         colorHex: String = "#007AFF", onSave: @escaping (String, String, String) -> Void) {
        self.title = title
        self._name = State(initialValue: name)
        self._symbol = State(initialValue: symbol)
        self._color = State(initialValue: Color(hex: colorHex))
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.headline)

            // Preview
            HStack {
                Spacer()
                Image(systemName: symbol)
                    .font(.system(size: 36))
                    .foregroundStyle(color)
                Spacer()
            }
            .padding(.vertical, 8)

            // Name
            TextField("Collection name", text: $name)
                .textFieldStyle(.roundedBorder)

            // Color
            ColorPicker("Symbol color", selection: $color, supportsOpacity: false)

            // Symbol picker
            Text("Symbol")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 36))], spacing: 8) {
                    ForEach(commonSymbols, id: \.self) { sym in
                        Button {
                            symbol = sym
                        } label: {
                            Image(systemName: sym)
                                .font(.system(size: 16))
                                .frame(width: 32, height: 32)
                                .foregroundStyle(symbol == sym ? color : .secondary)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(symbol == sym ? color.opacity(0.15) : Color.clear)
                                )
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .frame(height: 140)

            // Buttons
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") {
                    guard !name.isEmpty else { return }
                    onSave(name, symbol, color.toHex())
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 300, height: 420)
    }
}
