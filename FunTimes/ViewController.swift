//
//  ViewController.swift
//  FunTimes
//
//  Created by Tanner W. Stokes on 6/20/18.
//  Copyright © 2018 Tanner W. Stokes. All rights reserved.
//

import UIKit
import ARKit
import SceneKit
import SpriteKit

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!

    var animals = [Animal]()

    // for thread safety
    let updateQueue = DispatchQueue(label: Bundle.main.bundleIdentifier! +
        ".serialSceneKitQueue")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        // sceneView.showsStatistics = true

        animals = loadAnimals()
    }

    func loadAnimals() -> [Animal] {
        let kyrie = Animal(
            name: "Kyrie",
            type: .miniSchnauzer,
            dob: "Born: Jan 2004",
            description: "Loves bananas 🍌\nBarks like a rooster 🐓",
            uiBgColor: UIColor.purple
        )

        let olive = Animal(
            name: "Olive",
            type: .miniSchnauzer,
            dob: "Born: Nov 2011",
            description: "Hates squirrels 🐿\nSounds like a pig 🐷",
            uiBgColor: UIColor(hue: 0, saturation: 0.61, brightness: 1, alpha: 1.0)
        )

        // todo - add baby emoji?
        let stokes = Animal(
            name: "Baby Stokes",
            type: .human,
            dob: "Expected: Jan 2019",
            description: "Currently the size \nof a grape 🍇",
            uiBgColor: UIColor.orange
        )

        return [kyrie, olive, stokes]
    }

    override func viewDidAppear(_ animated: Bool) {
        // prevent screen dimming
        UIApplication.shared.isIdleTimerDisabled = true

        guard let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil) else {
            fatalError("Missing expected asset catalog resources.")
        }

        let configuration = ARWorldTrackingConfiguration()
        configuration.maximumNumberOfTrackedImages = 2
        configuration.detectionImages = referenceImages
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }

    // MARK: - ARSCNViewDelegate

    // TODO - if an image goes away, so should its UI node
    
    // image detection results
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
//        renderer.debugOptions.insert(SCNDebugOptions.showBoundingBoxes)

        guard let imageAnchor = anchor as? ARImageAnchor else { return }
        let referenceImage = imageAnchor.referenceImage
        let imageName = referenceImage.name ?? ""
        debugPrint("Found \(imageName)")

        updateQueue.async {

//            let overlayNode = self.generateOverlayNode(for: referenceImage)
//            node.addChildNode(overlayNode)

            guard
                let animal = self.animals.first(where: {$0.name == imageName}),
                let uiNode = self.generateUINode(for: animal)
            else {
                return
            }

            node.addChildNode(uiNode)

            if animal.type == .human {
                if let particleSystem = SCNParticleSystem(named: "Confetti", inDirectory: nil) {
                    particleSystem.particleDiesOnCollision = false
                    node.addParticleSystem(particleSystem)                }
            }
        }
    }

    // plane that overlays the detected image
    func generateOverlayNode(for referenceImage: ARReferenceImage) -> SCNNode {
        let plane = SCNPlane(width: referenceImage.physicalSize.width,
                             height: referenceImage.physicalSize.height)

        let planeNode = SCNNode(geometry: plane)
        planeNode.opacity = 0.25
        planeNode.eulerAngles.x = -.pi / 2

        return planeNode
    }

    // ui that augments a node
    func generateUINode(for animal: Animal) -> SCNNode? {
        guard let scene = SKScene(fileNamed: "SpriteScene.sks") else {
            debugPrint("Failed to load SpriteKit scene!")
            return nil
        }

        // w:h ratio matches the SpriteKit Scene
        let width: CGFloat = 0.1
        let height: CGFloat = 0.075
        let cornerRadius: CGFloat = 5

        let uiPlane = SCNPlane(
            width: width,
            height: height
        )

        uiPlane.cornerRadius = min(width, height) * cornerRadius / 100

        scene.backgroundColor = animal.uiBgColor
        scene.backgroundColor = scene.backgroundColor.withAlphaComponent(0.75)
        fillUILabels(inside: scene, for: animal)
        uiPlane.firstMaterial?.diffuse.contents = scene
        uiPlane.firstMaterial?.isDoubleSided = true

        // we need to translate the node's coordinates
        let uiPlaneNode = SCNNode(geometry: uiPlane)

        uiPlaneNode.eulerAngles.z = .pi
        uiPlaneNode.eulerAngles.y = .pi
        uiPlaneNode.eulerAngles.x = -.pi / 2
        // nudge to the right
        uiPlaneNode.position.x = 0.10
        // start off hidden
        uiPlaneNode.opacity = 0
        uiPlaneNode.runAction(fadeIn)

        // run the scene animations
        scene.isPaused = false

        return uiPlaneNode
    }

    func fillUILabels(inside scene: SKScene, for animal: Animal) {
        guard
            let name = scene.childNode(withName: "name") as? SKLabelNode,
            let dob = scene.childNode(withName: "dob") as? SKLabelNode,
            let type = scene.childNode(withName: "type") as? SKLabelNode,
            let description = scene.childNode(withName: "description") as? SKLabelNode
        else {
            debugPrint("Failed to load all the labels from the UI!")
            return
        }

        name.text = animal.name
        dob.text = animal.dob
        type.text = animal.type.description

        // we have to clone the attributed text to a mutable copy
        // and just change the string piece
        guard
            let attributedText = description.attributedText,
            let mutableAttributedText = attributedText.mutableCopy() as? NSMutableAttributedString
        else {
            debugPrint("Failed to change attributed text!")
            return
        }

        mutableAttributedText.mutableString.setString(animal.description)
        description.attributedText = mutableAttributedText
    }

    var fadeIn: SCNAction {
        return .fadeIn(duration: 0.25)
    }

    var fadeOut: SCNAction {
        return .sequence([
            .fadeOut(duration: 0.5),
            .removeFromParentNode()
        ])
    }

    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        debugPrint("An anchor was removed")
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}
