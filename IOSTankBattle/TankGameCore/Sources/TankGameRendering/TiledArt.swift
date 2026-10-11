import CoreGraphics
import TankGameCore

/// Flattens the tile layers of a Tiled map into one image, the way the editor
/// draws them: bottom layer first, each tile anchored on the bottom-left corner
/// of its cell, flips applied.
///
/// One image rather than a sprite per tile, because a board scaled down to fit
/// a phone puts tile edges on fractional pixels, and separate sprites then show
/// hairline seams between them. It also keeps a 16 x 20 map at one node.
enum TiledArt {

    /// The whole map at the tilesets' own resolution, or nil if any tileset a
    /// visible layer uses has no image — half a map is worse than the fallback.
    static func compose(_ map: TiledMap, sheet: (TiledMap.Tileset) -> CGImage?) -> CGImage? {
        let width = map.width * map.tileWidth
        let height = map.height * map.tileHeight
        guard width > 0, height > 0,
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.interpolationQuality = .none

        var sheets: [Int: CGImage] = [:]   // by first gid
        for layer in map.layers where layer.isVisible {
            context.setAlpha(CGFloat(layer.opacity))
            for y in 0..<map.height {
                for x in 0..<map.width {
                    guard let tile = map.tile(in: layer, at: Position(x: x, y: y)) else { continue }
                    let set = tile.tileset
                    if sheets[set.firstGID] == nil { sheets[set.firstGID] = sheet(set) }
                    guard let image = sheets[set.firstGID] else { return nil }

                    let source = set.pixelRect(of: tile.localID)
                    guard let piece = image.cropping(to: CGRect(x: source.x, y: source.y,
                                                                width: source.width, height: source.height))
                    else { continue }

                    // CoreGraphics counts y up from the bottom; the map counts rows down.
                    let cell = CGRect(x: x * map.tileWidth,
                                      y: (map.height - 1 - y) * map.tileHeight,
                                      width: source.width, height: source.height)
                    draw(piece, in: cell, flippedFor: tile, context: context)
                }
            }
        }
        return context.makeImage()
    }

    /// Draws `piece` into `rect`, turned as Tiled's flip flags say: the diagonal
    /// flip (an x/y swap) first, then horizontal, then vertical.
    private static func draw(_ piece: CGImage, in rect: CGRect,
                             flippedFor tile: TiledMap.TileRef, context: CGContext) {
        guard tile.flippedHorizontally || tile.flippedVertically || tile.flippedDiagonally else {
            context.draw(piece, in: rect)
            return
        }
        // In a y-up frame centred on the tile, the swap maps (x, y) to (-y, -x).
        var transform = tile.flippedDiagonally
            ? CGAffineTransform(a: 0, b: -1, c: -1, d: 0, tx: 0, ty: 0)
            : .identity
        if tile.flippedHorizontally { transform = transform.concatenating(CGAffineTransform(scaleX: -1, y: 1)) }
        if tile.flippedVertically { transform = transform.concatenating(CGAffineTransform(scaleX: 1, y: -1)) }

        context.saveGState()
        context.translateBy(x: rect.midX, y: rect.midY)
        context.concatenate(transform)
        context.draw(piece, in: CGRect(x: -rect.width / 2, y: -rect.height / 2,
                                       width: rect.width, height: rect.height))
        context.restoreGState()
    }
}
