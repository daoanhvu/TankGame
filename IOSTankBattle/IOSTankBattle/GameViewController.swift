//
//  GameViewController.swift
//  IOSTankBattle
//
//  Created by Vu Dao on 2/10/26.
//

import UIKit
import SpriteKit
import TankGameCore
import TankGameRendering

/// Hosts the board. Everything about the game itself lives in the two
/// libraries; this controller only owns the `SKView`.
class GameViewController: UIViewController {

    private var scene: BattleScene?

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let skView = view as? SKView else {
            assertionFailure("Main.storyboard should give this controller an SKView")
            return
        }
        skView.ignoresSiblingOrder = true

        #if DEBUG
        skView.showsFPS = true
        skView.showsNodeCount = true

        // A live to-do list for the art: empty once milestone 4 is imported.
        let missing = SpriteCatalog().missingRequiredAssets()
        if !missing.isEmpty {
            print("Using placeholder shapes for \(missing.count) missing assets: "
                  + missing.joined(separator: ", "))
        }
        #endif
    }

    /// The scene is built here rather than in `viewDidLoad` so it starts at the
    /// real device size instead of the storyboard's, which keeps the board
    /// centered on the first frame.
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        guard let skView = view as? SKView,
              skView.bounds.width > 0, skView.bounds.height > 0 else { return }

        // Keep the HUD out from under the notch and the home indicator, also
        // after a rotation.
        if let scene {
            scene.safeAreaInsets = currentInsets()
            return
        }

        do {
            // Phase 1: one handmade map, hot-seat for two players.
            let scene = try BattleScene(size: skView.bounds.size, map: Maps.crossing)
            scene.safeAreaInsets = currentInsets()
            self.scene = scene
            skView.presentScene(scene)
        } catch {
            // A broken built-in map is a programming error, not something the
            // player can recover from, so say so loudly in debug builds.
            assertionFailure("Could not start a match: \(error)")
            showStartupFailure(error)
        }
    }

    private func currentInsets() -> BoardInsets {
        BoardInsets(top: view.safeAreaInsets.top, bottom: view.safeAreaInsets.bottom)
    }

    private func showStartupFailure(_ error: Error) {
        let label = UILabel()
        label.text = "Could not start a match.\n\(error)"
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
        ])
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
