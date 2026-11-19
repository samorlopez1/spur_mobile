import Foundation

enum FeedFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case images = "Images"
    case videos = "Videos"
    case links = "Links"

    var id: Self { self }
}

enum FeedItemKind {
    case image, video, link
}

/// Portrait and square ratios used by the placeholder feed, expressed as width / height.
enum FeedAspectRatio: CaseIterable {
    case threeByFour, twoByThree, nineBySixteen, square

    var value: CGFloat {
        switch self {
        case .threeByFour: 3.0 / 4.0
        case .twoByThree: 2.0 / 3.0
        case .nineBySixteen: 9.0 / 16.0
        case .square: 1
        }
    }
}

struct FeedItem: Identifiable {
    let id: Int
    let title: String
    let kind: FeedItemKind
    let aspectRatio: FeedAspectRatio

    /// Seeded placeholder photo so each item keeps the same image across launches.
    var imageURL: URL {
        let width = 600
        let height = Int((CGFloat(width) / aspectRatio.value).rounded())
        return URL(string: "https://picsum.photos/seed/spur\(id)/\(width)/\(height)")!
    }

    func matches(_ filter: FeedFilter) -> Bool {
        switch filter {
        case .all: true
        case .images: kind == .image
        case .videos: kind == .video
        case .links: kind == .link
        }
    }
}

extension FeedItem {
    static let placeholders: [FeedItem] = {
        let ratios: [FeedAspectRatio] = [
            .threeByFour, .square, .twoByThree, .nineBySixteen, .threeByFour, .twoByThree,
            .square, .nineBySixteen, .twoByThree, .threeByFour, .nineBySixteen, .square,
        ]
        let kinds: [FeedItemKind] = [.image, .image, .link, .image, .video, .image]
        return (0..<24).map { index in
            let kind = kinds[index % kinds.count]
            return FeedItem(
                id: index,
                title: "\(kind == .link ? "Link" : kind == .video ? "Video" : "Image") \(index + 1)",
                kind: kind,
                aspectRatio: ratios[index % ratios.count]
            )
        }
    }()
}
