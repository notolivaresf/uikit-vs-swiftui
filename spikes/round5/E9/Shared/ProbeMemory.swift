import Darwin

extension Probe {
    /// Current and peak physical footprint (MB) from TASK_VM_INFO, the number the memory metric reads.
    static func memory() -> (now: Double, peak: Double) {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) }
        }
        guard kr == KERN_SUCCESS else { return (0, 0) }
        return (Double(info.phys_footprint) / 1_048_576, Double(info.ledger_phys_footprint_peak) / 1_048_576)
    }

    static func sayMemory(_ tag: String) {
        let m = memory()
        say(String(format: "MEM %@ now %.1f peak %.1f", tag, m.now, m.peak))
    }
}
