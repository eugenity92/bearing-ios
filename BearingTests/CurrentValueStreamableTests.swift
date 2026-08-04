import Foundation
import Testing
@testable import Bearing

struct CurrentValueStreamableTests {
    @Test func newSubscriberImmediatelyReceivesCurrentValue() async {
        let streamable = CurrentValueStreamable(7)

        var received: Int?
        for await value in await streamable.updates {
            received = value
            break
        }

        #expect(received == 7)
    }

    @Test func updateChangesTheStoredValue() async {
        let streamable = CurrentValueStreamable(1)
        await streamable.update { $0 = 42 }

        #expect(await streamable.value == 42)
    }

    @Test func subscriberSeesReplayThenSubsequentUpdates() async {
        let streamable = CurrentValueStreamable("initial")
        let stream = await streamable.updates

        let collected = Task {
            var values: [String] = []
            for await value in stream {
                values.append(value)
                if values.count == 3 { break }
            }
            return values
        }

        await streamable.update { $0 = "second" }
        await streamable.update { $0 = "third" }

        #expect(await collected.value == ["initial", "second", "third"])
    }

    @Test func twoSubscribersBothReceiveTheSameUpdate() async {
        let streamable = CurrentValueStreamable(0)
        let first = await streamable.updates
        let second = await streamable.updates

        let firstValues = Task { await collectTwo(from: first) }
        let secondValues = Task { await collectTwo(from: second) }

        await streamable.update { $0 = 99 }

        #expect(await firstValues.value == [0, 99])
        #expect(await secondValues.value == [0, 99])
    }

    @Test func finishEndsActiveStreams() async {
        let streamable = CurrentValueStreamable(1)
        let stream = await streamable.updates

        let drained = Task {
            var count = 0
            for await _ in stream { count += 1 }
            return count
        }

        await streamable.finish()

        #expect(await drained.value == 1)
    }

    private func collectTwo(from stream: AsyncStream<Int>) async -> [Int] {
        var values: [Int] = []
        for await value in stream {
            values.append(value)
            if values.count == 2 { break }
        }
        return values
    }
}
