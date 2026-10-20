enum Corpus {
    static let first = ["Ana","Ben","Carla","Dmitri","Elena","Farid","Gwen","Hiro","Iris","Jonas","Kofi","Lena","Mateo","Noor","Oskar","Priya","Quinn","Rosa","Sven","Tara","Uma","Viktor","Wren","Xavier","Yara","Zoe"]
    static let last = ["Alder","Brook","Castillo","Dahl","Ericsen","Fontaine","Garza","Haas","Ito","Jensen","Khan","Lopez","Moreau","Nakamura","Okafor","Petrov","Quist","Rivera","Silva","Tanaka"]
    static let words = ["the","a","we","ship","it","today","build","fix","review","deploy","server","on","call","meeting","later","lunch","ready","maybe","yes","no","thanks","looks","good","bug","patch","release","design","draft","update","link","check","this","that","can","you","please","look","at","before","friday","notes","figma","tests","green","red","flaky","cache","queue","room","chat","message","photo","coffee","walk","plan","scope","launch","blocked","unblocked","done","soon","great","hmm","wait","really","sure","agreed","ok","tomorrow","morning","night","demo","slides","budget","invoice","customer","feedback","metrics","latency","scroll","list","cell","height","image","upload","download"]
    static let emoji = ["👍","🎉","🔥","😂","❤️","👏","👋","💪","🙌","🤔"]
    static let reactions = ["👍","👏","👋","💪","❤️","😂","🎉","🔥"]
    static let textBoosts = ["Nice!","lol","On it","+1","agreed","Agreed!","Thanks","Same"]
    static let codeSnippets: [(String?, String)] = [
        ("ruby", "def greet(name)\n  puts \"hello #{name}\"\nend"),
        ("swift", "let ids = messages.map(\\.id)\nprint(ids.count)"),
        ("sh", "kamal deploy\ncurl -I https://example.test/up"),
        (nil, "SELECT id, body\nFROM messages\nORDER BY created_at DESC\nLIMIT 40;"),
    ]
    static let fileNames = ["notes.pdf","budget.xlsx","logo.zip","minutes.txt","report.docx"]
}
