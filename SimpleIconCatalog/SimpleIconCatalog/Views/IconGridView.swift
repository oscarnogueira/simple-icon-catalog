import SwiftUI

struct IconGridView: View {
    let icons: [IconItem]
    let thumbnailSize: CGFloat
    let cache: ThumbnailCache
    @ObservedObject var viewModel: IconCatalogViewModel

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: thumbnailSize + 16), spacing: 12)]
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(icons) { icon in
                    IconCellView(item: icon, thumbnailSize: thumbnailSize, cache: cache, viewModel: viewModel)
                        .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                }
            }
            .padding()
            .animation(.easeInOut(duration: 0.2), value: icons.map(\.id))
        }
    }
}
