import Foundation

actor CurrentValueStreamable<Value: Sendable> {
    private var storage: Value
    private var continuations: [UUID: AsyncStream<Value>.Continuation] = [:]

    var value: Value { storage }

    var updates: AsyncStream<Value> {
        let currentValue = storage
        return AsyncStream<Value> { continuation in
            let id = UUID()
            continuations[id] = continuation
            continuation.yield(currentValue)
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id: id) }
            }
        }
    }

    init(_ initialValue: Value) {
        storage = initialValue
    }

    deinit {
        continuations.values.forEach { $0.finish() }
    }

    func update(_ action: @Sendable (inout Value) -> Void) {
        action(&storage)
        continuations.values.forEach { $0.yield(storage) }
    }

    func finish() {
        continuations.values.forEach { $0.finish() }
        continuations.removeAll()
    }
}

private extension CurrentValueStreamable {
    func removeContinuation(id: UUID) {
        continuations[id] = nil
    }
}
