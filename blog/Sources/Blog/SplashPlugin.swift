//
//  SplashPlugin.swift
//  
//
//  Created by Joe Diragi on 8/12/22.
//

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
