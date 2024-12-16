import SwiftUI

struct RefreshableView<Content: View>: View {
    let isRefreshing: Bool
    let onRefresh: () async -> Void
    let content: () -> Content
    
    @State private var offset: CGFloat = 0
    @State private var isRefreshTriggered = false
    private let refreshThreshold: CGFloat = 50
    
    init(
        isRefreshing: Bool,
        onRefresh: @escaping () async -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isRefreshing = isRefreshing
        self.onRefresh = onRefresh
        self.content = content
    }
    
    var body: some View {
        ScrollView {
            ZStack(alignment: .top) {
                MovingView(offset: offset, isRefreshing: isRefreshing)
                    .frame(height: max(0, offset))
                    .opacity(offset > 0 ? 1 : 0)
                    .zIndex(1)
                
                content()
                    .offset(y: max(0, offset))
                    .zIndex(0)
            }
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: ScrollOffsetPreferenceKey.self,
                        value: proxy.frame(in: .named("scroll")).minY
                    )
                }
            )
        }
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            if !isRefreshing {
                if value > refreshThreshold && !isRefreshTriggered {
                    isRefreshTriggered = true
                    offset = refreshThreshold
                    Task {
                        await onRefresh()
                        withAnimation {
                            offset = 0
                            isRefreshTriggered = false
                        }
                    }
                } else if value >= 0 {
                    offset = value
                }
            }
        }
    }
}

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct MovingView: View {
    let offset: CGFloat
    let isRefreshing: Bool
    private let refreshThreshold: CGFloat = 50
    
    var body: some View {
        HStack(spacing: 12) {
            if isRefreshing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(0.8)
            } else {
                Image(systemName: "arrow.down")
                    .font(.system(size: 16, weight: .semibold))
                    .rotationEffect(.degrees(Double(min(180.0 * (offset / refreshThreshold), 180.0))))
            }
            
            Text(isRefreshing ? "Refreshing..." : "Pull to refresh")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 8)
        .frame(height: 40)
    }
}
