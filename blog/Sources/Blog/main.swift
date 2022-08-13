import Foundation
import Publish
import Plot
import Splash

// This type acts as the configuration for your website.
struct Blog: Website {
    enum SectionID: String, WebsiteSectionID {
        // Add the sections that you want your website to contain here:
        case home
        case posts
        case about
    }

    struct ItemMetadata: WebsiteItemMetadata {
        // Add any site-specific metadata that you want to use here.
    }

    // Update these properties to configure your website:
    var url = URL(string: "https://www.jdiggity.me")!
    var name = "Joe's Blog"
    var description = "A cautionary tale on the horrors of programming ❤️"
    var language: Language { .english }
    var imagePath: Path? { nil }
}



// This will generate your website using the built-in Foundation theme:
try Blog().publish(
    using: [
        .installPlugin(.splashPlugin(withClassPrefix: "", withGrammars: [(grammar: YamlGrammar(), name: "yaml"), (grammar: SwiftGrammar(), "swift")])),
    .addMarkdownFiles(),
    .copyResources(),
    .generateHTML(withTheme: .blog),
    .generateRSSFeed(including: [.posts]),
    .generateSiteMap(),
])
