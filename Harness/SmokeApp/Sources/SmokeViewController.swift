import UIKit
import CampfireKit

/// Throwaway app that only proves the benchmark harness works. It fulfils the debug-bar contract in PROMPT.md
/// with plain default cells and nothing else; it looks nothing like Campfire on purpose.
/// It has a context menu (Copy, Reply) but no text selection, so the capability test sees one yes and one no.
final class SmokeViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let dataset = FakeData.generate(size: .k50)
    private var loaded: [Message] = []
    private let table = UITableView(frame: .zero, style: .plain)
    private let stateLabel = UILabel()
    private let doneLabel = UILabel()
    private var streamTask: Task<Void, Never>?
    private var burstTask: Task<Void, Never>?
    private var pinned = true
    private var lastMs = 0
    private var tapTime: CFTimeInterval?
    private let sizes: [UIContentSizeCategory] = [.large, .extraLarge, .extraExtraLarge, .extraExtraExtraLarge,
                                                  .accessibilityMedium, .accessibilityLarge]
    private var sizeIndex = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let titles: [(String, Selector)] = [("Reset", #selector(reset)), ("Jump to 2500", #selector(jump)),
                                            ("Load older", #selector(older)), ("Start stream", #selector(startStream)),
                                            ("Text size +", #selector(textSize)), ("Boost burst", #selector(boostBurst))]
        let buttons = titles.map { title, action -> UIButton in
            var config = UIButton.Configuration.bordered()
            config.title = title
            let b = UIButton(configuration: config)
            b.addTarget(self, action: #selector(touchUp), for: .touchUpInside)
            b.addTarget(self, action: action, for: .touchUpInside)
            return b
        }
        let rows = stride(from: 0, to: buttons.count, by: 3).map { i -> UIStackView in
            let r = UIStackView(arrangedSubviews: Array(buttons[i..<i + 3])); r.distribution = .fillEqually; r.spacing = 6
            return r
        }
        stateLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        stateLabel.adjustsFontSizeToFitWidth = true
        doneLabel.text = "Stream done"
        doneLabel.isHidden = true
        let bar = UIStackView(arrangedSubviews: rows + [stateLabel, doneLabel])
        bar.axis = .vertical; bar.spacing = 4
        bar.translatesAutoresizingMaskIntoConstraints = false
        table.translatesAutoresizingMaskIntoConstraints = false
        table.dataSource = self; table.delegate = self
        table.contentInsetAdjustmentBehavior = .never
        table.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        view.addSubview(bar); view.addSubview(table)
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            bar.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            bar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            table.topAnchor.constraint(equalTo: bar.bottomAnchor, constant: 6),
            table.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            table.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
        loaded = Array(Windowing.lastPage(dataset.messages))
        table.reloadData()
        scrollToBottom()
        lastMs = Int((CACurrentMediaTime() - launchStart) * 1000)
        updateState()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        lastMs = Int((CACurrentMediaTime() - launchStart) * 1000)
        updateState()
    }

    // MARK: state label

    @objc private func touchUp() { tapTime = CACurrentMediaTime() }

    /// Called after a tap's result is laid out.
    private func finishTap() {
        table.layoutIfNeeded()
        if let t = tapTime { lastMs = Int((CACurrentMediaTime() - t) * 1000) }
        tapTime = nil
        updateState()
    }

    private var isAtBottom: Bool {
        table.contentOffset.y + table.bounds.height >= table.contentSize.height - 100
    }

    private func topRow() -> (id: Int, y: CGFloat)? {
        guard let ip = table.indexPathsForVisibleRows?.sorted().first(where: {
            table.rectForRow(at: $0).maxY > table.contentOffset.y
        }) else { return nil }
        return (loaded[ip.row].id, table.rectForRow(at: ip).minY - table.contentOffset.y)
    }

    private func updateState() {
        let top = topRow()
        let y = String(format: "%.1f", top?.y ?? 0)
        stateLabel.text = "first \(loaded.first?.id ?? 0) last \(loaded.last?.id ?? 0) loaded \(loaded.count) pinned \(pinned ? "yes" : "no") top \(top?.id ?? 0) y \(y) ms \(lastMs)"
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { pinned = isAtBottom; updateState() }
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { pinned = isAtBottom; updateState() }
    }

    private func scrollToBottom() {
        table.layoutIfNeeded()
        if !loaded.isEmpty { table.scrollToRow(at: IndexPath(row: loaded.count - 1, section: 0), at: .bottom, animated: false) }
    }

    /// Keeps message `id`'s top at `y` below the header.
    private func restore(id: Int, y: CGFloat) {
        table.layoutIfNeeded()
        guard let i = loaded.firstIndex(where: { $0.id == id }) else { return }
        table.contentOffset.y = table.rectForRow(at: IndexPath(row: i, section: 0)).minY - y
    }

    // MARK: actions

    @objc private func reset() {
        streamTask?.cancel(); burstTask?.cancel()
        doneLabel.isHidden = true
        sizeIndex = 0
        traitOverrides.preferredContentSizeCategory = sizes[0]
        loaded = Array(Windowing.lastPage(dataset.messages))
        table.reloadData()
        scrollToBottom()
        pinned = true
        finishTap()
    }

    @objc private func jump() {
        loaded = Array(Windowing.around(2_500, in: dataset.messages))
        table.reloadData()
        table.layoutIfNeeded()
        if let i = loaded.firstIndex(where: { $0.id == 2_500 }) {
            table.scrollToRow(at: IndexPath(row: i, section: 0), at: .top, animated: false)
        }
        pinned = false
        finishTap()
    }

    @objc private func older() {
        guard let first = loaded.first else { return }
        let anchor = topRow()
        let page = Array(Windowing.page(before: first.id, in: dataset.messages))
        guard !page.isEmpty else { finishTap(); return }
        loaded = page + loaded
        table.reloadData()
        if let a = anchor { restore(id: a.id, y: a.y) }
        pinned = isAtBottom
        finishTap()
    }

    @objc private func textSize() {
        let anchor = topRow()
        sizeIndex = (sizeIndex + 1) % sizes.count
        traitOverrides.preferredContentSizeCategory = sizes[sizeIndex]
        view.setNeedsLayout(); view.layoutIfNeeded()
        table.reloadData()
        if pinned { scrollToBottom() } else if let a = anchor { restore(id: a.id, y: a.y) }
        finishTap()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        let anchor = topRow()
        let wasPinned = pinned
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { _ in
            if wasPinned { self.scrollToBottom() } else if let a = anchor { self.restore(id: a.id, y: a.y) }
            self.updateState()
        }
    }

    @objc private func boostBurst() {
        tapTime = nil
        burstTask?.cancel()
        burstTask = Task { @MainActor in
            for _ in 0..<5 {
                try? await Task.sleep(nanoseconds: 200_000_000)
                if Task.isCancelled { return }
                if !self.loaded.isEmpty {
                    self.table.reloadRows(at: [IndexPath(row: self.loaded.count - 1, section: 0)], with: .none)
                    if self.pinned { self.scrollToBottom() }
                }
                self.updateState()
            }
        }
    }

    @objc private func startStream() {
        tapTime = nil
        streamTask?.cancel()
        doneLabel.isHidden = true
        let feed = FakeLiveFeed(dataset: dataset)
        streamTask = Task { @MainActor in
            for await event in feed.play() {
                guard case .message(let m) = event else { continue }
                let wasPinned = self.pinned
                self.loaded.append(m)
                self.table.reloadData()
                if wasPinned { self.scrollToBottom() }
                self.updateState()
            }
            if !Task.isCancelled { self.doneLabel.isHidden = false }
        }
    }

    // MARK: table

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { loaded.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let m = loaded[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = "#\(m.id) " + m.plainText
        content.textProperties.font = .preferredFont(forTextStyle: .body, compatibleWith: traitCollection)
        content.textProperties.numberOfLines = 2
        cell.contentConfiguration = content
        return cell
    }

    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath,
                   point: CGPoint) -> UIContextMenuConfiguration? {
        let text = loaded[indexPath.row].plainText
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            UIMenu(children: [
                UIAction(title: "Copy") { _ in UIPasteboard.general.string = text },
                UIAction(title: "Reply") { _ in },
            ])
        }
    }
}
