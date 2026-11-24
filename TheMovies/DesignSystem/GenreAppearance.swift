import SwiftUI

/// Visual identity (icon + gradient) for each TMDB genre id.
enum GenreAppearance {
    private static let symbols: [Int: String] = [
        28: "flame.fill", 12: "map.fill", 16: "sparkles", 35: "face.smiling.inverse",
        80: "lock.fill", 99: "video.fill", 18: "theatermasks.fill",
        10751: "figure.2.and.child.holdinghands", 14: "wand.and.stars",
        36: "building.columns.fill", 27: "moon.stars.fill", 10402: "music.note",
        9648: "magnifyingglass", 10749: "heart.fill", 878: "atom", 10770: "tv.fill",
        53: "bolt.fill", 10752: "shield.fill", 37: "sun.dust.fill",
    ]

    private static let palettes: [[Color]] = [
        [Color(red: 1.0, green: 0.36, blue: 0.42), Color(red: 0.55, green: 0.1, blue: 0.35)],
        [Color(red: 1.0, green: 0.64, blue: 0.27), Color(red: 0.75, green: 0.25, blue: 0.15)],
        [Color(red: 0.35, green: 0.55, blue: 1.0), Color(red: 0.2, green: 0.15, blue: 0.6)],
        [Color(red: 0.3, green: 0.85, blue: 0.65), Color(red: 0.05, green: 0.4, blue: 0.45)],
        [Color(red: 0.75, green: 0.45, blue: 1.0), Color(red: 0.3, green: 0.12, blue: 0.55)],
        [Color(red: 1.0, green: 0.45, blue: 0.75), Color(red: 0.5, green: 0.15, blue: 0.5)],
        [Color(red: 0.25, green: 0.8, blue: 1.0), Color(red: 0.05, green: 0.3, blue: 0.55)],
    ]

    static func symbol(for genreID: Int) -> String {
        symbols[genreID] ?? "film.fill"
    }

    static func colors(for genreID: Int) -> [Color] {
        palettes[abs(genreID) % palettes.count]
    }

    static func gradient(for genreID: Int) -> LinearGradient {
        LinearGradient(colors: colors(for: genreID), startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
