import SwiftUI

extension Color {
    static let spurBackground = Color(red: 0xEF / 255, green: 0xEF / 255, blue: 0xEF / 255)
    static let spurInk = Color(red: 0x24 / 255, green: 0x24 / 255, blue: 0x24 / 255)
}

struct ContentView: View {
    @State private var filter: FeedFilter = .all
    @State private var query = ""
    @State private var isSearching = false
    @State private var isHeaderHidden = false
    @State private var headerHeight: CGFloat = 0

    private var visibleItems: [FeedItem] {
        FeedItem.placeholders.filter { item in
            item.matches(filter)
                && (query.isEmpty || item.title.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        ScrollView {
            MasonryFeed(items: visibleItems)
                .opacity(isSearching ? 0.5 : 1)
        }
        .contentMargins(.top, headerHeight, for: .scrollContent)
        .scrollDismissesKeyboard(.immediately)
        .onScrollGeometryChange(for: FeedScrollMetrics.self) { geometry in
            FeedScrollMetrics(
                offset: geometry.contentOffset.y + geometry.contentInsets.top,
                maxOffset: geometry.contentSize.height + geometry.contentInsets.top
                    + geometry.contentInsets.bottom - geometry.containerSize.height
            )
        } action: { old, new in
            updateHeaderVisibility(from: old, to: new)
        }
        .background(Color.spurBackground)
        .overlay(alignment: .top) {
            // Soft white fade behind the status bar, visible once the header hides.
            LinearGradient(stops: Self.statusBarFadeStops, startPoint: .top, endPoint: .bottom)
                .frame(height: 62)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .top) {
            FilterHeader(selection: $filter, isDimmed: isSearching, onAdd: { /* TODO: present add-content flow */ })
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }
                .offset(y: isHeaderHidden ? -20 : 0)
                .opacity(isHeaderHidden ? 0 : 1)
                .blur(radius: isHeaderHidden ? 8 : 0)
                .allowsHitTesting(!isHeaderHidden)
                .animation(.timingCurve(0.42, 0, 0.25, 1, duration: 0.3), value: isHeaderHidden)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SearchBar(query: $query, isExpanded: $isSearching)
        }
    }

    /// White-to-clear stops sampled along an ease-in-out (smoothstep) curve.
    private static let statusBarFadeStops: [Gradient.Stop] = stride(from: 0.0, through: 1.0, by: 0.1).map { t in
        let eased = t * t * (3 - 2 * t)
        return Gradient.Stop(color: .white.opacity(1 - eased), location: t)
    }

    /// Hides the header while scrolling down the feed and reveals it on any upward scroll or at the top.
    private func updateHeaderVisibility(from old: FeedScrollMetrics, to new: FeedScrollMetrics) {
        if new.offset <= 0 {
            isHeaderHidden = false
            return
        }
        // Ignore rubber-banding past the end so the bounce back doesn't reveal the header.
        guard new.offset < new.maxOffset, old.offset < old.maxOffset else { return }

        let delta = new.offset - old.offset
        if delta > 2 {
            isHeaderHidden = true
        } else if delta < -2 {
            isHeaderHidden = false
        }
    }
}

private struct FeedScrollMetrics: Equatable {
    let offset: CGFloat
    let maxOffset: CGFloat
}

// MARK: - Header

private struct FilterHeader: View {
    @Binding var selection: FeedFilter
    let isDimmed: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack {
            HStack(spacing: 10) {
                ForEach(FeedFilter.allCases) { filter in
                    Button(filter.rawValue) {
                        selection = filter
                    }
                    .foregroundStyle(selection == filter ? Color.black : Color.black.opacity(0.4))
                }
            }
            .font(.callout.weight(.medium))
            .tracking(-0.16)
            .buttonStyle(.plain)

            Spacer()

            Button(action: onAdd) {
                Image(.plusIcon)
                    .resizable()
                    .frame(width: 12, height: 12)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.spurInk, in: .capsule)
                    .contentShape(.capsule)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add")
        }
        .opacity(isDimmed ? 0.5 : 1)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.spurBackground, ignoresSafeAreaEdges: .top)
    }
}

// MARK: - Feed

private struct MasonryFeed: View {
    let items: [FeedItem]

    private static let spacing: CGFloat = 8

    /// Greedily places each item in whichever column is currently shorter.
    private var columns: [[FeedItem]] {
        var columns: [[FeedItem]] = [[], []]
        var heights: [CGFloat] = [0, 0]
        for item in items {
            let target = heights[0] <= heights[1] ? 0 : 1
            columns[target].append(item)
            heights[target] += 1 / item.aspectRatio.value
        }
        return columns
    }

    var body: some View {
        HStack(alignment: .top, spacing: Self.spacing) {
            ForEach(columns.indices, id: \.self) { index in
                LazyVStack(spacing: Self.spacing) {
                    ForEach(columns[index]) { item in
                        FeedTile(item: item)
                    }
                }
            }
        }
        .padding(Self.spacing)
    }
}

private struct FeedTile: View {
    let item: FeedItem

    var body: some View {
        Color.black.opacity(0.06)
            .aspectRatio(item.aspectRatio.value, contentMode: .fit)
            .overlay {
                AsyncImage(url: item.imageURL, transaction: Transaction(animation: .easeOut)) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    }
                }
            }
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Image(systemName: badge)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(.black.opacity(0.4), in: .circle)
                        .padding(8)
                }
            }
            .clipped()
            .accessibilityLabel(item.title)
    }

    private var badge: String? {
        switch item.kind {
        case .image: nil
        case .video: "play.fill"
        case .link: "link"
        }
    }
}

// MARK: - Bottom search

private struct SearchBar: View {
    @Binding var query: String
    @Binding var isExpanded: Bool
    @FocusState private var isFocused: Bool

    private static let animation = Animation.timingCurve(0.42, 0, 0.25, 1, duration: 0.15)
    private static let placeholder = Color(red: 0xB3 / 255, green: 0xB3 / 255, blue: 0xB3 / 255)

    var body: some View {
        HStack(spacing: 8) {
            if isExpanded {
                TextField("", text: $query, prompt: Text("Search collection").foregroundStyle(Self.placeholder))
                    .font(.callout)
                    .tracking(-0.16)
                    .focused($isFocused)
                    // Focus once the field is on screen; setting it in the same update that inserts it is ignored.
                    .onAppear { isFocused = true }
                    .submitLabel(.search)
                    .padding(.horizontal, 16)
                    .frame(height: 42)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .modifier(SearchPill(isSolid: true))
                    // The field pops in almost instantly while the rest of the change runs the full 150ms.
                    .transition(.opacity.animation(.easeOut(duration: 0.04)))
            }

            Button(action: toggle) {
                ZStack {
                    Image(.searchIcon)
                        .resizable()
                        .opacity(isExpanded ? 0 : 1)
                    Image(.closeIcon)
                        .resizable()
                        .opacity(isExpanded ? 1 : 0)
                }
                .frame(width: 15, height: 15)
                .foregroundStyle(Color.spurInk)
                .frame(height: 42)
                .padding(.horizontal, 24)
                .contentShape(.capsule)
            }
            .buttonStyle(.plain)
            .padding(6)
            .modifier(SearchPill(isSolid: isExpanded))
            .accessibilityLabel(isExpanded ? "Close search" : "Search")
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.horizontal, isExpanded ? 12 : 24)
        .padding(.top, 16)
        .padding(.bottom, isExpanded ? 16 : 0)
        .background {
            // Fade starts a little above the search row and runs to the bottom screen edge.
            LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .top, endPoint: .bottom)
                .padding(.top, -45)
                .ignoresSafeArea(edges: .bottom)
                .opacity(isExpanded ? 0 : 1)
                .allowsHitTesting(false)
        }
    }

    private func toggle() {
        if isExpanded {
            isFocused = false
            withAnimation(Self.animation) {
                query = ""
                isExpanded = false
            }
        } else {
            withAnimation(Self.animation) { isExpanded = true }
        }
    }
}

/// Capsule behind the search controls: frosted while idle, solid white with a hairline border while searching.
private struct SearchPill: ViewModifier {
    let isSolid: Bool

    func body(content: Content) -> some View {
        content
            .background(.white.opacity(isSolid ? 1 : 0.8), in: .capsule)
            .background(.ultraThinMaterial, in: .capsule)
            .overlay(Capsule().strokeBorder(.black.opacity(isSolid ? 0.1 : 0)))
    }
}

#Preview {
    ContentView()
}
