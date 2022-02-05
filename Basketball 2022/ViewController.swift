//
//  ViewController.swift
//  Basketball 2022
//
//  Created by notwo on 2/2/22.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate, SCNPhysicsContactDelegate {
    // MARK: - Outlets
    @IBOutlet var sceneView: ARSCNView!
    
    // MARK: - Properties
    fileprivate var isContactDetected = false
    
    fileprivate var throwsTextNode: SCNNode! = nil
    fileprivate var throwsText: SCNText! = nil
    
    fileprivate var hitsTextNode: SCNNode! = nil
    fileprivate var hitsText: SCNText! = nil
    
    fileprivate var numberOfThrows: Int = 0
    fileprivate var numberOfHits: Int = 0
    
    // Create a session configuration
    fileprivate let configuration = ARWorldTrackingConfiguration()
    
    fileprivate var isBasketballFieldAdded = false {
        didSet {
            configuration.planeDetection = []
            sceneView.session.run(configuration, options: .removeExistingAnchors)
        }
    }
    
    fileprivate let CollisionCategoryPoint: Int = 4
    fileprivate let CollisionCategoryBall: Int = 8
    
    
    // MARK: - UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        sceneView.scene.physicsWorld.contactDelegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Detect vertical planes
        configuration.planeDetection = [.vertical, .horizontal]
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    // MARK: - Methods
    
    func getBall() -> SCNNode? {
        // get current frame
        guard let frame = sceneView.session.currentFrame else {return nil}
        
        // get camera transform
        let cameraTransform = frame.camera.transform
        let matrixCameraTranform = SCNMatrix4(cameraTransform)
        
        let ball = SCNSphere(radius: 0.125)
        ball.firstMaterial?.diffuse.contents = UIImage(named: "basketball-texture.png")
        let ballNode = SCNNode(geometry: ball)
        
        ballNode.name = "ball"
        // add physics
        ballNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(node: ballNode))
        
        // setting its category- and contact- bit mask
        ballNode.physicsBody!.categoryBitMask = CollisionCategoryBall
        ballNode.physicsBody!.contactTestBitMask = CollisionCategoryPoint
        
        // calculating force power and direction
        let power = Float(5)
        let x = -matrixCameraTranform.m31 * power
        let y = -matrixCameraTranform.m32 * power
        let z = -matrixCameraTranform.m33 * power
        let forceDirection = SCNVector3(x, y, z)
        
        // apply force
        ballNode.physicsBody?.applyForce(forceDirection, asImpulse: true)
        
        
        // assign camera position to the ball
        ballNode.simdTransform = cameraTransform
        return ballNode
    }
    
    func getBasketballSceneNode() -> SCNNode {
        let scene = SCNScene(named: "basketball.scn", inDirectory: "art.scnassets")!
        let basketballSceneNode = scene.rootNode.clone()
        
        // Add physics body - making node static and concavePolyhedron
        basketballSceneNode.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(node: basketballSceneNode, options: [SCNPhysicsShape.Option.type: SCNPhysicsShape.ShapeType.concavePolyhedron]))
        
        // Rotate scene node to make it vertical
        basketballSceneNode.eulerAngles.x -= .pi/2
        
        
        // geting nodes for throws and hits number 3Dtext fields and setting initial 0's
        throwsTextNode = scene.rootNode.childNode(withName: "throws number", recursively: true)
        throwsText = throwsTextNode?.geometry as? SCNText
        throwsText.string = "\(numberOfThrows)"
        
        hitsTextNode = scene.rootNode.childNode(withName: "hits number", recursively: true)
        hitsText = hitsTextNode?.geometry as? SCNText
        hitsText.string = "\(numberOfHits)"
        
        
        // Add the checkpoint node to basketballscene node
        basketballSceneNode.addChildNode(getCheckPointNode())
        
        return basketballSceneNode
    }
    
    func getCheckPointNode() -> SCNNode {
        
        // Creating checkpoint which when passed indicates a hit
        let checkPointGeometry = SCNSphere(radius: 0.001)
        let checkPointNode = SCNNode(geometry: checkPointGeometry)
        
        // position it under the hoop
        checkPointNode.position = SCNVector3(x: 0.0, y: -0.5, z: 0.23)
        checkPointNode.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(node: checkPointNode, options: [SCNPhysicsShape.Option.type: SCNPhysicsShape.ShapeType.concavePolyhedron]))
        checkPointNode.name = "cpNode"
        
        // setting its category- and collision- bit masks
        checkPointNode.physicsBody!.categoryBitMask = CollisionCategoryPoint
        checkPointNode.physicsBody!.collisionBitMask = 0
        
        return checkPointNode
    }
    
    func getVerticalPlaneNode(for anchor: ARPlaneAnchor) -> SCNNode {
        
        let extent = anchor.extent
        let plane = SCNPlane(width: CGFloat(extent.x), height: CGFloat(extent.z))
        plane.firstMaterial?.diffuse.contents = UIColor.green
        let planeNode = SCNNode(geometry: plane)
        planeNode.opacity = 0.25
        // rotate plane node
        planeNode.eulerAngles.x -= .pi/2
        return planeNode
    }
    
    func updatePlaneNode(_ node: SCNNode, for anchor: ARPlaneAnchor) {
        guard let planeNode = node.childNodes.first, let plane = planeNode.geometry as? SCNPlane else {
            return
        }
        
        // change plane node center
        planeNode.simdPosition = anchor.center
        // change plane size
        let extent = anchor.extent
        plane.width = CGFloat(extent.x)
        plane.height = CGFloat(extent.z)
    }
    
    // MARK: - ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor, planeAnchor.alignment == .vertical else {
            return
        }
        
        // Add the basketball scene to the center of detected vertical plane
        node.addChildNode(getVerticalPlaneNode(for: planeAnchor))
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor, planeAnchor.alignment == .vertical else {
            return
        }
        // update plane node
        updatePlaneNode(node, for: planeAnchor)
    }
    
    // MARK: - Actions
    @IBAction func userTapped(_ sender: UITapGestureRecognizer) {
        
        if isBasketballFieldAdded {
            // get balls
            guard let ballNode = getBall() else {return}
            
            // let balls vanish in 5 sec
            ballNode.runAction(.sequence([
                .wait(duration: 5),
                .fadeOut(duration: 0),
                .removeFromParentNode()]))
            
            numberOfThrows += 1
            isContactDetected = false
            
            // add balls to the camera position
            sceneView.scene.rootNode.addChildNode(ballNode)
            
            // updating number of throws
            throwsText.string = "\(numberOfThrows)"
            
        } else {
            let location = sender.location(in: sceneView)
            guard let result = sceneView.hitTest(location, types: .existingPlaneUsingExtent).first else {
                return
            }
            guard let anchor = result.anchor as? ARPlaneAnchor, anchor.alignment == .vertical else {
                return
            }
            // Get basketball field node and set its coordinates to the user touch
            let basketballFieldNode = getBasketballSceneNode()
            basketballFieldNode.simdTransform = result.worldTransform
            // rotate node by 90 degrees
            basketballFieldNode.eulerAngles.x -= .pi/2
            isBasketballFieldAdded = true
            sceneView.scene.rootNode.addChildNode(basketballFieldNode)
        }
    }
    
    
    func physicsWorld(_ world: SCNPhysicsWorld, didEnd contact: SCNPhysicsContact) {
        // Collision happened between contact.nodeA and contact.nodeB
        guard let nodeNameA = contact.nodeA.name else {return}
        guard let nodeNameB = contact.nodeB.name else {return}
        
        guard !isContactDetected else {return}
        if nodeNameA == "ball" && nodeNameB == "cpNode" {
            numberOfHits += 1
            hitsText.string = "\(numberOfHits)"
            isContactDetected = true
        } else if nodeNameB == "ball" && nodeNameA == "cpNode" {
            numberOfHits += 1
            hitsText.string = "\(numberOfHits)"
            isContactDetected = true
        }
    }
}



