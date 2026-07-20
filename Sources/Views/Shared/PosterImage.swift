import SwiftUI
import UIKit

// A poster/thumbnail loader for video tiles — the iOS counterpart of manage's
// `<VideoThumb posterUrl=…>` fast path, which paints a stored JPEG instead of
// waiting on the video itself.
//
// Why not plain AsyncImage (#1071): AsyncImage keeps no cache of its own and
// restarts its request every time its view is re-created. Inside the Released
// tab's LazyVStack that happens on every scroll recycle, so an already-fetched
// poster flashes back to black and is re-downloaded. PosterImage adds:
//
//   1. an in-memory cache of DECODED images, read synchronously in `init`, so a
//      recycled tile paints its poster in the first frame with no flash; and
//   2. a disk-backed URLCache on a private session, so posters survive a cold
//      launch and the grid fills in immediately on the second run.
//
// It also renders `file://` URLs, which AsyncImage cannot — that is what the
// bundled offline UITest fixtures use.
struct PosterImage: View {
    let url: URL
    @State private var image: UIImage?

    init(url: URL) {
        self.url = url
        // Synchronous cache hit = poster is on screen in the first frame. This is
        // the whole point: `@State` initial value, not a value assigned in .task
        // one runloop later.
        _image = State(initialValue: PosterCache.shared.cached(url))
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    // Surfaced as its own element so a UITest can assert the
                    // poster actually painted. Inside a Button label SwiftUI
                    // would otherwise fold it into the button and the
                    // identifier would be unqueryable.
                    .accessibilityElement()
                    .accessibilityIdentifier("angle-poster")
            } else {
                // Black rather than a spinner: the tile is already black, so a
                // miss looks like the pre-poster state instead of flickering
                // chrome into a 110pt box.
                Color.black
            }
        }
        // Cancels automatically when the tile scrolls out of the LazyVStack, and
        // re-runs when the tile is recycled onto a different angle.
        //
        // Keyed on `url`, and it must NOT early-out on "already have an image":
        // SwiftUI keeps @State across a recycle, so the image sitting here is the
        // PREVIOUS angle's poster. Skipping the load would leave the wrong frame
        // on the tile permanently.
        .task(id: url) {
            // Cache hit swaps straight to the right poster with no black gap.
            if let hit = PosterCache.shared.cached(url) {
                image = hit
                return
            }
            // Miss: drop the stale poster first, so a recycled tile shows black
            // rather than another angle's frame while this one loads.
            image = nil
            let loaded = await PosterCache.shared.load(url)
            // The tile may have been recycled onto another angle while this was
            // in flight; that run's .task is already cancelled, so dropping the
            // result here stops it overwriting the newer angle's poster.
            guard !Task.isCancelled else { return }
            image = loaded
        }
    }
}

// Shared poster store: decoded images in memory, encoded bytes on disk.
//
// Deliberately its own URLSession rather than mutating `URLCache.shared` — the
// shared cache would have to be resized before anything else touches the
// network, and Firebase starts making requests at launch.
actor PosterCache {
    static let shared = PosterCache()

    // Decoded images. NSCache evicts under memory pressure on its own, so a long
    // scroll can't grow unbounded. `totalCostLimit` is in bytes of pixel data.
    // `nonisolated(unsafe)` so the first-frame read below can touch it straight
    // from the view's init: NSCache does its own locking, so this is safe.
    nonisolated(unsafe) private let memory: NSCache<NSURL, UIImage> = {
        let c = NSCache<NSURL, UIImage>()
        c.countLimit = 240
        c.totalCostLimit = 64 * 1024 * 1024
        return c
    }()

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.urlCache = URLCache(memoryCapacity: 8 * 1024 * 1024,
                                diskCapacity: 128 * 1024 * 1024,
                                diskPath: "palmr-posters")
        // Posters are immutable once written (the generator uploads to a
        // per-camera path with a fresh token), so a cached copy is always good.
        cfg.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: cfg)
    }()

    // In-flight loads, so three tiles asking for the same poster make one
    // request instead of three.
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]

    // Synchronous, non-isolated read for the first-frame paint. Safe off the
    // actor: NSCache is thread-safe, and this only ever reads.
    nonisolated func cached(_ url: URL) -> UIImage? {
        memory.object(forKey: url as NSURL)
    }

    func load(_ url: URL) async -> UIImage? {
        if let hit = cached(url) { return hit }
        if let running = inFlight[url] { return await running.value }

        let task = Task<UIImage?, Never> { [session] in
            let data: Data?
            if url.isFileURL {
                data = try? Data(contentsOf: url)
            } else {
                data = try? await session.data(for: URLRequest(url: url)).0
            }
            guard let data, let raw = UIImage(data: data) else { return nil }
            // Decode + colour-convert off the main thread. Without this the
            // first draw of each tile does that work during the scroll.
            return await raw.byPreparingForDisplay() ?? raw
        }
        inFlight[url] = task
        let image = await task.value
        inFlight[url] = nil

        if let image {
            memory.setObject(image, forKey: url as NSURL, cost: image.byteCost)
        }
        return image
    }
}

private extension UIImage {
    // Approximate decoded size, for NSCache's cost accounting.
    var byteCost: Int {
        guard let cg = cgImage else { return 1 }
        return cg.bytesPerRow * cg.height
    }
}
