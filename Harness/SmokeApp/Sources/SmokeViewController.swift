import UIKit
import CampfireKit

/// Throwaway app that only proves the benchmark harness works. It fulfils the debug-bar contract in PROMPT.md
/// with plain default cells and nothing else; it looks nothing like Campfire on purpose.
final class SmokeViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let dataset = FakeData.generate(size: .k50)
    private var loaded: [Message] = []
    private let table = UITableView(frame: .zero, style: .plain)
    private let stateLabel = UILabel()
    private let doneLabel = UILabel()
    private var streamTask: Task<Void, Never>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let titles: [(String, Selector)] = [("Reset", #selector(reset)), ("Jump to 2500", #selector(jump)),
                                            ("Load older", #selector(older)), ("Start stream", #selector(startStream))]
        let buttons = titles.map { title, action -> UIButton in
            var config = UIButton.Configuration.bordered()
            config.title = title
            let b = UIButton(configuration: config)
            b.addTarget(self, action: action, for: .touchUpInside)
            return b
        }
        let rowA = UIStackView(arrangedSubviews: Array(buttons[0..<2])); rowA.distribution = .fillEqually; rowA.spacing = 8
        let rowB = UIStackView(arrangedSubviews: Array(buttons[2..<4])); rowB.distribution = .fillEqually; rowB.spacing = 8
        stateLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        doneLabel.text = "Stream done"
        doneLabel.isHidden = true
        let bar = UIStackView(arrangedSubviews: [rowA, rowB, stateLabel, doneLabel])
        bar.axis = .vertical; bar.spacing = 6
        bar.translatesAutoresizingMaskIntoConstraints = false
        table.translatesAutoresizingMaskIntoConstraints = false
        table.dataSource = self; table.delegate = self
        table.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        view.addSubview(bar); view.addSubview(table)
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            table.topAnchor.constraint(equalTo: bar.bottomAnchor, constant: 6),
            table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            table.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        reset()
    }

    private var isPinned: Bool {
        table.contentOffset.y + table.bounds.height >= table.contentSize.height - 100
    }

    private func updateState(pinned: Bool? = nil) {
        stateLabel.text = "first \(loaded.first?.id ?? 0), last \(loaded.last?.id ?? 0), loaded \(loaded.count), pinned \((pinned ?? isPinned) ? "yes" : "no")"
    }

    private func scrollToBottom() {
        table.layoutIfNeeded()
        if !loaded.isEmpty { table.scrollToRow(at: IndexPath(row: loaded.count - 1, section: 0), at: .bottom, animated: false) }
    }

    @objc private func reset() {
        streamTask?.cancel()
        doneLabel.isHidden = true
        loaded = Array(Windowing.lastPage(dataset.messages))
        table.reloadData()
        scrollToBottom()
        updateState(pinned: true)
    }

    @objc private func jump() {
        loaded = Array(Windowing.around(2_500, in: dataset.messages))
        table.reloadData()
        if let i = loaded.firstIndex(where: { $0.id == 2_500 }) {
            table.scrollToRow(at: IndexPath(row: i, section: 0), at: .middle, animated: false)
        }
        updateState()
    }

    @objc private func older() {
        guard let first = loaded.first else { return }
        let page = Array(Windowing.page(before: first.id, in: dataset.messages))
        guard !page.isEmpty else { return }
        loaded = page + loaded
        table.reloadData()
        table.scrollToRow(at: IndexPath(row: page.count, section: 0), at: .top, animated: false)
        updateState()
    }

    @objc private func startStream() {
        streamTask?.cancel()
        doneLabel.isHidden = true
        let feed = FakeLiveFeed(dataset: dataset)
        streamTask = Task { @MainActor in
            for await event in feed.play() {
                guard case .message(let m) = event else { continue }
                let pinned = self.isPinned
                self.loaded.append(m)
                self.table.reloadData()
                if pinned { self.scrollToBottom() }
                self.updateState(pinned: pinned)
            }
            if !Task.isCancelled { self.doneLabel.isHidden = false }
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { loaded.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let m = loaded[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = "#\(m.id) " + m.plainText
        content.textProperties.numberOfLines = 2
        cell.contentConfiguration = content
        return cell
    }
}
