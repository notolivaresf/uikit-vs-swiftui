import UIKit
import SpikeKit

/// E1 spike A: a table view. Saved heights come from the shared measurer; rows are inserted one at a time.
final class TableAdapter: NSObject, ListAdapter, UITableViewDataSource, UITableViewDelegate {
    private let table = UITableView(frame: .zero, style: .plain)
    weak var data: RoomDataProviding?
    var scrollView: UIScrollView { table }

    override init() {
        super.init()
        table.separatorStyle = .none
        table.allowsSelection = false
        table.dataSource = self
        table.delegate = self
        table.register(TableRowCell.self, forCellReuseIdentifier: "row")
    }

    func reloadAll() { cache.removeAll(); table.reloadData() }
    func heightsChanged() { cache.removeAll(); table.reloadData() }

    func rowsAppended(_ count: Int) {
        guard let n = data?.itemCount else { return }
        let paths = ((n - count)..<n).map { IndexPath(row: $0, section: 0) }
        let pinned = table.isPinnedToBottom
        UIView.performWithoutAnimation {
            table.beginUpdates()
            table.insertRows(at: paths, with: .none)
            table.endUpdates()
            if pinned { table.scrollToRow(at: paths[paths.count - 1], at: .bottom, animated: false) }
        }
    }

    func rowsPrepended(_ count: Int) {
        let paths = (0..<count).map { IndexPath(row: $0, section: 0) }
        UIView.performWithoutAnimation {
            table.performBatchUpdates { table.insertRows(at: paths, with: .none) }
        }
    }

    func rowChanged(_ index: Int) {
        if let id = data?.messageID(at: index) { cache[id] = nil }
        UIView.performWithoutAnimation { table.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none) }
    }

    func rowFrame(_ index: Int) -> CGRect { table.rectForRow(at: IndexPath(row: index, section: 0)) }
    func visibleTopRow() -> Int? { table.indexPathsForVisibleRows?.min()?.row }

    // MARK: Data source and delegate

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { data?.itemCount ?? 0 }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "row", for: indexPath) as! TableRowCell
        data?.configure(cell.row, at: indexPath.row)
        return cell
    }

    /// Diagnosis (Round 5 follow-up): `defaults write -g uvsCache 1` in the simulator keeps the answer by message id, so
    /// the table's repeated height questions (it asks for every row on each insert) do not rebuild a RowItem each time.
    private let cacheOn = UserDefaults.standard.bool(forKey: "uvsCache")
    private var cache: [Int: CGFloat] = [:]
    private func rowHeight(_ row: Int) -> CGFloat {
        guard let data else { return 0 }
        guard cacheOn else { return data.savedHeight(at: row) }
        let id = data.messageID(at: row)
        if let h = cache[id] { return h }
        let h = data.savedHeight(at: row); cache[id] = h; return h
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { rowHeight(indexPath.row) }
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat { rowHeight(indexPath.row) }
    func scrollViewDidScroll(_ scrollView: UIScrollView) { data?.listDidScroll() }
}
