---
date: 2022-08-13 13:32
description: How I struggled to find a static site generator with proper syntax highlighting and friendly templating
tags: swift, publish, static-site-generators, syntax-highlighting
---

# The Grimm Adventures of Choosing a Static Site Generator

I'm still new to this whole *technical blogging* thing. I've spent the majority of my time so far jumping between different static site generators when I should've been using that time to go back to 8th grade spelling and grammar.

I just wanted to find a generator that made me feel cool. [Publish](), for instance, made me feel super bleeding edge. It's a relatively young SSG; it's first commit was pushed in 2019! [Hugo]() was another contender, since it's written in `go` and has a large and, most importantly, active userbase. I also tried out [VuePress](), which had me excited to use `vue.js` in my layouts.

Immediately, though, `publish` stood out to me. The other frameworks had me building page templates in raw HTML using different templating engines, but, `publish` let me create my layouts using `swift` in a very similar fashion to `swiftUI`. Just look at how cool `publish` is:

```swift
func makeIndexHTML(for index: Index, context: PublishingContext<Blog>) throws -> HTML {
    HTML (
        .lang(context.site.language),
        .head(for: index, on: context.site),
        .body {
            SiteHeader(context: context, selectedSelectionID: nil)
            Wrapper {
                H1(index.title)
                    .style("text-align: center;")
                Paragraph(context.site.description)
                    .class("description")
                H2("Latest content")
                ItemList(
                    items: context.allItems(
                        sortedBy: \.date,
                        order: .descending
                    ),
                    site: context.site
                )
            }
            SiteFooter()
        }
    )
}
```

It's *extremely* approachable for someone who hasn't had the (great dis)pleasure of dealing with raw HTML/CSS in a long time. Of course, I still needed to make stylesheets with css, but it wasn't so bad! 

## Publish

As I stated earler, I *love* using `publish` for static site generation. I even posted a guide on using GitHub Actions to generate and deploy `publish` sites to GitHub Pages. You can check that out [here](/publish-ghactions) if you want.

But after fully committing and getting deep into the project I started to hit some roadblocks. The first of which I went over in my other post (linked above), but to recap I had no luck getting the built-in deploy functionality to work with GitHub Pages. Every time I tried publishing using the command line tool my terminal froze up while it was trying to push to the repo. I think the publish utility was meant to work only for people who have their codebase untracked on a local machine, or in a seperate repo. I took a look at the code and the publish function is basically just `cd`ing to the `Output` directory, initializing a git repo and trying to push. That didn't seem to work inside of an existing git repo.

The second (worst and final as well) issue I hit was a devastating lack of syntax highlighting. Programming is my entire blog. Every single post I make will include code snippets and sometimes those code snippets *aren't* swift. Publish comes with a pretty impressive syntax highlighting utility called [Splash](https://github.com/johnsundell/splash). It's really cool and works really well but, unfortunately, only for swift. Splash definitely has the potential to work with other languages. In fact, someone has added [support for Kotlin](https://github.com/JZDesign/Splash/blob/kotlinGrammar2/Sources/Splash/Grammar/KoltinGrammar.swift). The only problem is it takes a **lot** of work to add support for another language. You may call me lazy. You may say, "If you want support for other languages so bad why don't you add it yourself?" And to that I say: 

## Creating a custom syntax highlighter for YAML using Splash

I went ahead and gave it my all. I dug deep into the [swift grammar](https://github.com/JohnSundell/Splash/blob/master/Sources/Splash/Grammar/SwiftGrammar.swift) and worked out how the original author implemented the Swift syntax highlighter. I won't bore you with the details, but it wasn't too bad. Too sum up, I created a new struct that implements `Grammar`. I defined a list of delimiters that basically tell the parser where each part of the code starts and stops. We then create several `SyntaxRule`s that are called when the parser reaches a new token.

Since `yaml` isn't exactly a programming language, it wasn't too difficult to create a highlighter for it. I simply created rules for comments that checks if the current line begins with a `#`, a string rule that's a little more complex, and rules for types and keywords that simply check if the current token is a part of a predefined list.

Here's what `YamlGrammar` wound up looking like:

```swift
public struct YamlGrammar: Grammar {
    public var delimiters: CharacterSet
    public var syntaxRules: [SyntaxRule]
    
    public init() {
        var delimiters = CharacterSet.alphanumerics.inverted
        delimiters.remove("_")
        delimiters.remove("-")
        delimiters.remove("\"")
        delimiters.remove("#")
        delimiters.remove("@")
        delimiters.remove("$")
        self.delimiters = delimiters
        
        syntaxRules = [
            KeywordRule(),
            TypeRule(),
            StringRule(),
            CommentRule(),
            NumberRule()
        ]
    }
    
    public func isDelimiter(_ delimiterA: Character, mergableWith delimiterB: Character) -> Bool {
        switch (delimiterA, delimiterB) {
        case (_, ":"):
            return false
        case (":", "/"):
            return true
        case (":", _):
            return false
        case ("-", _):
            return false
        case ("#", _):
            return false
        default:
            return true
        }
    }
}

private extension YamlGrammar {
    static let keywords = ([
        "|", "---", "...", ">", "[", "]", "-"
    ] as Set<String>)
    
    struct CommentRule: SyntaxRule {
        var tokenType: TokenType { return .comment }
        
        func matches(_ segment: Segment) -> Bool {
            if segment.tokens.onSameLine.contains("#") {
                return true
            }
            
            return segment.tokens.current.hasPrefix("#")
        }
    }
    
    struct StringRule: SyntaxRule {
        var tokenType: TokenType { return .string }
        
        func matches(_ segment: Segment) -> Bool {
            if let prev = segment.tokens.previous {
                /**
                 *  In yaml files, quotes around strings are optional
                 *  Unless it's a number, a value following a colon or lines after a pipe (|) are considered a string
                 */
                if prev.hasSuffix(":") {
                    if let next = segment.tokens.next {
                        if segment.tokens.current.hasSuffix(":") && next.hasSuffix(":") {
                            /**
                             * ie.
                             *  name:
                             *    name2: << This is not a string
                             *      ...
                             */
                            return false
                        }
                        return true
                    }
                } else {
                    var sameLine: Bool = false
                    segment.tokens.onSameLine.forEach( { token in
                        if token.hasSuffix(":") {
                            sameLine = true
                        }
                    })
                    if sameLine {
                        return true
                    }
                }
            }
            if segment.tokens.current == ":" {
                return false
            }
            return true
        }
    }
    
    struct NumberRule: SyntaxRule {
        var tokenType: TokenType { return .number }
        
        func matches(_ segment: Segment) -> Bool {
            if segment.tokens.current.isNumber {
                return true
            }
            
            guard segment.tokens.current == "." else {
                return false
            }
            
            guard let prev = segment.tokens.previous, let next = segment.tokens.next else {
                return false
            }
            
            return prev.isNumber && next.isNumber
        }
    }
    
    struct KeywordRule: SyntaxRule {
        var tokenType: TokenType { return .keyword }
        
        func matches(_ segment: Segment) -> Bool {
            return keywords.contains(segment.tokens.current)
        }
    }
    
    struct TypeRule: SyntaxRule {
        var tokenType: TokenType { return .type }
        
        func matches(_ segment: Segment) -> Bool {
            if let next = segment.tokens.next {
                return next.hasSuffix(":")
            } else {
                return false
            }
        }
    }
}

extension String  {
    var isNumber: Bool {
        return !isEmpty && rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil
    }
}
```

By far the hardest part was the string rule. This is because we don't actually have access to the previous line of code when we are checking the current token. Ideally, I would have gone back over the last tokens until I hit a `|` to confirm if the token was inside of a multiline comment. If iterating led us to a colon instead, the token is not inside of a multiline comment. Instead I had to cheat and essentially say if the token doesn't fit into anything else, it's a multiline string. I believe there is a better way to do this, but I haven't been able to work it out just yet.

So now we have our `yaml` grammar rules, what next? Well the official `SplashPublishPlugin` does not allow the use of custom `Grammar`s. I submitted a [pull request](https://github.com/JohnSundell/SplashPublishPlugin/pull/8) on GitHub, but haven't gotten a response yet. Instead of waiting for that to be merged I went ahead and wrote my own implementation of the plugin.

It looks like this:

```swift
import Publish
import Splash
import Ink

public extension Plugin {
    static func splashPlugin(withClassPrefix classPrefix: String = "", withGrammars grammars: [(grammar: Grammar, name: String)] = [(SwiftGrammar(), "swift")]) -> Self {
        Plugin(name: "Splash") { context in
            context.markdownParser.addModifier(.splashCodeBlocks(withFormat: HTMLOutputFormat(classPrefix: classPrefix), withGrammars: grammars)
            )
        }
    }
}

public extension Modifier {
    static func splashCodeBlocks(withFormat format: HTMLOutputFormat = .init(), withGrammars grammars: [(grammar: Grammar, name: String)] = [(SwiftGrammar(), "swift")]) -> Self {
        var highlighter = SyntaxHighlighter(format: format)
        return Modifier(target: .codeBlocks) { html, md in
            var markdown = md.dropFirst("```".count)
            
            guard !markdown.hasPrefix("no-highlight") else {
                return html
            }
            grammars.forEach({ grammar, name in
                if markdown.hasPrefix(name) {
                    highlighter = SyntaxHighlighter(format: format, grammar: grammar)
                }
            })
            
            markdown = markdown
                .drop(while: { !$0.isNewline })
                .dropFirst()
                .dropLast("\n```".count)
            
            let highlighted = highlighter.highlight(String(markdown))
            return "<pre><code>" + highlighted + "\n</code></pre>"
        }
    }
}
```

Almost exactly like the official plugin, with the addition of a `grammars` argument in the plugin method. The method takes a list of tuples that contain both a `Grammar` and the desired name of said grammar. Then, when applying the grammars, I loop through each of the provided tuples to see if this section matches up with any of the provided `name`s. If we find a match, we highlight that section using `SyntaxHighlighter` with the provided `grammar`. 

This code goes into a swift file and is imported in my `main.swift` and used like so:

```swift
try Blog().publish(
    using: [
    .installPlugin(
        .splashPlugin(
            withClassPrefix: "", 
            withGrammars: [
                (grammar: YamlGrammar(), name: "yaml"), 
                (grammar: SwiftGrammar(), "swift")
            ]
        )
    ),
    .addMarkdownFiles(),
    ...
    ]
)
```

And now both `yaml` and `swift` code blocks are syntax highlighted across my website!

Overall, getting `yaml` syntax highlighting wasn't too bad. I do worry, however, that adding a language like `golang` or `C++` might be a kind of monumental task. 

For now, I'll be sticking mergableWith `publish`. If the day comes that I need syntax highlighting for a more complex language and I just can't work it out, I might need to look into switching to something like `hugo` that already has plugins that support a vast majority of languages.
