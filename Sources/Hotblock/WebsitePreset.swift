import Foundation

enum WebsitePreset: String, CaseIterable, Identifiable {
    case news = "News"
    case socialMedia = "Social Media"
    case entertainment = "Entertainment"

    var id: String { rawValue }

    var websites: [String] {
        let domains: [String]
        switch self {
        case .news:
            domains = [
                "aftonbladet.se", "aljazeera.com", "apnews.com", "axios.com",
                "barrons.com", "bbc.com", "bloomberg.com", "businessinsider.com",
                "cbsnews.com", "cnbc.com", "cnn.com", "dagensarena.se",
                "dagensindustri.se", "dailymail.co.uk", "dn.se", "economist.com",
                "espn.com", "euronews.com", "expressen.se", "financialtimes.com",
                "forbes.com", "fortune.com", "foxnews.com", "france24.com",
                "independent.co.uk", "latimes.com", "marketwatch.com", "metro.co.uk",
                "msnbc.com", "nbcnews.com", "news.com.au", "newsweek.com",
                "npr.org", "nytimes.com", "omni.se", "politico.com",
                "reuters.com", "riks.se", "skysports.com", "sr.se",
                "svd.se", "svt.se", "theatlantic.com", "theguardian.com",
                "thehill.com", "thetimes.com", "time.com", "tmz.com",
                "usatoday.com", "vanityfair.com", "variety.com", "vox.com",
                "washingtonexaminer.com", "washingtonpost.com", "wsj.com", "yle.fi",
            ]
        case .socialMedia:
            domains = [
                "500px.com", "9gag.com", "behance.net", "bereal.com",
                "bsky.app", "clubhouse.com", "dev.to", "deviantart.com",
                "discord.com", "dribbble.com", "facebook.com", "flickr.com",
                "gab.com", "github.com", "gitlab.com", "goodreads.com",
                "imgur.com", "instagram.com", "kick.com", "ko-fi.com",
                "lemmy.world", "line.me", "linkedin.com", "mastodon.social",
                "medium.com", "meetup.com", "messenger.com", "minds.com",
                "myspace.com", "nextdoor.com", "ok.ru", "parler.com",
                "patreon.com", "pinterest.com", "pixelfed.social", "producthunt.com",
                "quora.com", "reddit.com", "rumble.com", "signal.org",
                "snapchat.com", "stackoverflow.com", "stackexchange.com", "substack.com",
                "telegram.org", "threads.net", "tiktok.com", "tumblr.com",
                "twitch.tv", "twitter.com", "vimeo.com", "vk.com",
                "wechat.com", "whatsapp.com", "x.com", "youtube.com",
            ]
        case .entertainment:
            domains = [
                "9gag.com", "abc.com", "amc.com", "apple.com",
                "bandcamp.com", "bet365.com", "bilibili.com", "boardgamearena.com",
                "buzzfeed.com", "chess.com", "cinemax.com", "crackle.com",
                "crunchyroll.com", "dailymotion.com", "deezer.com", "discoveryplus.com",
                "disneyplus.com", "ea.com", "ebay.com", "epicgames.com",
                "espn.com", "fandango.com", "funimation.com", "gog.com",
                "hbomax.com", "hulu.com", "ign.com", "imdb.com",
                "itch.io", "kick.com", "last.fm", "letterboxd.com",
                "max.com", "metacritic.com", "mlb.com", "mubi.com",
                "nba.com", "netflix.com", "nfl.com", "nhl.com",
                "nintendo.com", "paramountplus.com", "peacocktv.com", "playstation.com",
                "plex.tv", "primevideo.com", "rottentomatoes.com", "soundcloud.com",
                "spotify.com", "steampowered.com", "steamcommunity.com", "tetris.com",
                "tidal.com", "tubitv.com", "twitch.tv", "vimeo.com",
                "vudu.com", "wikipedia.org", "xbox.com", "youtube.com",
            ]
        }
        return Array(Set(domains)).sorted()
    }
}
