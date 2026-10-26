#if DEBUG
import UIKit
import CampfireKit

/// Debug builds only (`-uvsFixtures top|bottom`): the reference rows from Fixtures/constants.json drawn with
/// the real measurer, cells and layout, to compare against the screenshots. Not part of the app.
final class FixtureViewController: UIViewController, UICollectionViewDataSource {
    private let layout = ChatLayout()
    private var cv: UICollectionView!
    private let header = HeaderView()
    private let composer = ComposerView()
    private let atBottom: Bool
    var midRow: Int?
    private var geos: [RowGeo] = []

    init(atBottom: Bool) {
        self.atBottom = atBottom
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }
    override var prefersStatusBarHidden: Bool { true }

    private static let names = [1: "Fernando", 2: "Ana", 3: "Ben", 4: "Cleo", 5: "Dan", 6: "Eve", 7: "Frank"]
    private static let colors: [Int: UInt32] = [1: 0xBF7C2A, 2: 0x698F9C, 3: 0x736B1E, 4: 0x3B3633, 5: 0x3B3633, 6: 0x3B3633, 7: 0xBF1B1B]

    private func rows() -> [(RowContent, RowFlags, [BoostItem])] {
        func t(_ day: Int, _ h: Int, _ m: Int) -> Date {
            let secs: Int = (day - 15) * 86_400 + h * 3600 + m * 60
            return Date(timeIntervalSince1970: 1_792_022_400 + TimeInterval(secs))
        }
        func row(_ id: Int, _ by: Int, _ date: Date, _ blocks: [Block], _ att: Attachment? = nil, emoji: Bool = false,
                 threaded: Bool = false, day: Bool = false, mention: Bool = false, boosts: [(Int, String)] = []) -> (RowContent, RowFlags, [BoostItem]) {
            (RowContent(id: id, creatorID: by, createdAt: date, blocks: blocks, attachment: att, isEmojiOnly: emoji),
             RowFlags(threaded: threaded, firstOfDay: day, mine: by == 1, mentionsMe: mention),
             boosts.map { BoostItem(boosterID: $0.0, content: $0.1) })
        }
        var out: [(RowContent, RowFlags, [BoostItem])] = []
        out.append(row(1, 2, t(15, 9, 0), [.text("Morning everyone, kicking off the week.")], day: true))
        out.append(row(2, 2, t(15, 9, 2), [.text("First thing: the new designs are in the shared folder.")], threaded: true))
        out.append(row(3, 3, t(15, 9, 10), [.text("Thanks Ana. I read through them twice and I have a lot of thoughts about the spacing on the settings screen, the way the headers collapse when you scroll, and whether the empty states should say something friendlier than they do today. Happy to talk it through on a call whenever works for you.")]))
        out.append(row(4, 1, t(15, 9, 12), [.text("Sounds good, let's do it after lunch.")]))
        out.append(row(5, 4, t(15, 9, 20), [.mention(1), .text(" can you review the PR before then?")], mention: true))
        out.append(row(6, 5, t(16, 10, 0), [], .image(width: 600, height: 400, color: RGB(r: 60, g: 120, b: 200)), day: true,
                boosts: [(2, "👍"), (3, "🔥"), (4, "❤️")]))
        out.append(row(7, 5, t(16, 10, 1), [.code(language: "ruby", source: "def greet(name)\n  puts \"Hello, #{name}!\"\nend")], threaded: true))
        out.append(row(8, 6, t(16, 10, 5), [], .file(name: "Quarterly-report.pdf", bytes: 245_000)))
        out.append(row(9, 7, t(16, 10, 10), [.text("🎉🔥")], emoji: true))
        out.append(row(10, 1, t(16, 10, 12), [.text("Nice work, all of you.")]))
        out.append(row(11, 6, t(16, 10, 14), [.text("One more thing worth saying: the release notes are drafted and waiting for approval, so if anybody has a last minute change, now is the time to speak up before we cut the build tonight.")],
                boosts: [(1, "Agreed!")]))
        return out
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.contentInsetAdjustmentBehavior = .never
        cv.contentInset = UIEdgeInsets(top: Metrics.headerHeight, left: 0, bottom: 0, right: 0)
        cv.dataSource = self
        cv.register(MessageCell.self, forCellWithReuseIdentifier: MessageCell.reuseID)
        cv.register(WelcomeView.self, forSupplementaryViewOfKind: ChatLayout.welcomeKind, withReuseIdentifier: WelcomeView.reuseID)
        view.addSubview(cv)
        view.addSubview(header)
        view.addSubview(composer)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let b = view.bounds
        header.frame = CGRect(x: 0, y: 0, width: b.width, height: Metrics.headerHeight)
        let ct = b.height - Metrics.composerBottomGap - Metrics.composerHeight
        composer.frame = CGRect(x: 0, y: ct, width: b.width, height: Metrics.composerHeight)
        let f = CGRect(x: 0, y: 0, width: b.width, height: ct - Metrics.listBottomGap)
        guard f != cv.frame else { return }
        cv.frame = f
        let people = People(name: { Self.names[$0] ?? "?" }, color: { Theme.hex(Self.colors[$0] ?? 0) })
        let m = Measurer(width: f.width, type: TypeScale(category: traitCollection.preferredContentSizeCategory), people: people)
        geos = rows().map { m.measure($0.0, $0.1, boosts: $0.2, revision: 0) }
        layout.setRows(heights: geos.map(\.height), gaps: geos.map(\.gapBefore), welcome: true, welcomeHeight: WelcomeView.height)
        cv.reloadData()
        cv.layoutIfNeeded()
        var y = atBottom ? max(-Metrics.headerHeight, layout.contentHeight - f.height) : -Metrics.headerHeight
        if let r = midRow { y = layout.top(r) - 100 }
        cv.contentOffset = CGPoint(x: 0, y: y)
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { geos.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let c = collectionView.dequeueReusableCell(withReuseIdentifier: MessageCell.reuseID, for: indexPath) as! MessageCell
        c.configure(geos[indexPath.item])
        return c
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: WelcomeView.reuseID, for: indexPath)
    }
}
#endif
