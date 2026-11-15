import AppKit
import SceneKit

/// The nodes that the animation moves, found again by group after building.
struct MascotRig {
    let scene: SCNScene
    let cameraNode: SCNNode
    let root: SCNNode
    let groups: [MascotModel.Group: SCNNode]
    let groupBasePositions: [MascotModel.Group: SCNVector3]
    let screenMaterial: SCNMaterial
}

/// Turns a `MascotModel` into SceneKit nodes with toon shading and outlines.
enum MascotSceneBuilder {
    static let cameraPosition = (x: 0.0, y: 2.9, z: 7.6)
    static let cameraTarget = (x: 0.0, y: 1.02, z: 0.0)
    static let verticalFieldOfView = 24.0
    static let shadowRadius = 1.15
    static let shadowOpacity = 0.13

    static func build(_ model: MascotModel) -> MascotRig {
        let scene = SCNScene()
        // The window shows through behind the robot.
        scene.background.contents = NSColor.clear

        let root = SCNNode()
        scene.rootNode.addChildNode(root)
        root.addChildNode(makeShadow())

        var groups: [MascotModel.Group: SCNNode] = [:]
        var basePositions: [MascotModel.Group: SCNVector3] = [:]
        for spec in model.groups {
            let node = SCNNode()
            node.position = vector(spec.position)
            basePositions[spec.group] = node.position
            groups[spec.group] = node
        }
        // Attach after all exist, so that the order of specs does not matter.
        for spec in model.groups {
            guard let node = groups[spec.group] else { continue }
            let parent = spec.parent.flatMap { groups[$0] } ?? root
            parent.addChildNode(node)
        }

        let outlineMaterial = makeOutlineMaterial()
        for part in model.parts {
            guard let group = groups[part.group] else { continue }
            let node = SCNNode(geometry: makeGeometry(part.shape))
            node.geometry?.firstMaterial = makeToonMaterial(hex: part.color)
            node.position = vector(part.position)
            applyAxis(part.shape, to: node)

            let hull = SCNNode(geometry: makeGeometry(part.shape))
            hull.geometry?.firstMaterial = outlineMaterial
            node.addChildNode(hull)
            group.addChildNode(node)
        }

        let screenMaterial = SCNMaterial()
        screenMaterial.lightingModel = .constant
        screenMaterial.isDoubleSided = false
        let plane = SCNPlane(width: CGFloat(model.screen.width), height: CGFloat(model.screen.height))
        plane.firstMaterial = screenMaterial
        let screenNode = SCNNode(geometry: plane)
        screenNode.position = vector(model.screen.position)
        groups[model.screen.group]?.addChildNode(screenNode)

        let cameraNode = makeCamera()
        scene.rootNode.addChildNode(cameraNode)
        return MascotRig(
            scene: scene, cameraNode: cameraNode, root: root, groups: groups,
            groupBasePositions: basePositions, screenMaterial: screenMaterial)
    }

    private static func vector(_ v: MascotModel.Vector) -> SCNVector3 {
        SCNVector3(CGFloat(v.x), CGFloat(v.y), CGFloat(v.z))
    }

    private static func makeGeometry(_ shape: MascotModel.Shape) -> SCNGeometry {
        switch shape {
        case .box(let width, let height, let depth, let cornerRadius):
            return SCNBox(
                width: CGFloat(width), height: CGFloat(height), length: CGFloat(depth),
                chamferRadius: CGFloat(cornerRadius))
        case .cylinder(let radius, let height, _):
            return SCNCylinder(radius: CGFloat(radius), height: CGFloat(height))
        case .sphere(let radius):
            return SCNSphere(radius: CGFloat(radius))
        }
    }

    /// SCNCylinder revolves around Y, so other axes are a fixed turn of the part node.
    private static func applyAxis(_ shape: MascotModel.Shape, to node: SCNNode) {
        guard case .cylinder(_, _, let axis) = shape else { return }
        switch axis {
        case .x: node.eulerAngles.z = CGFloat.pi / 2
        case .z: node.eulerAngles.x = CGFloat.pi / 2
        case .y: break
        }
    }

    private static func color(hex: String) -> NSColor {
        let rgb = MascotModel.rgb(hex: hex) ?? (red: 1, green: 0, blue: 1)
        return NSColor(srgbRed: CGFloat(rgb.red), green: CGFloat(rgb.green), blue: CGFloat(rgb.blue), alpha: 1)
    }

    private static func makeToonMaterial(hex: String) -> SCNMaterial {
        let material = SCNMaterial()
        // Constant lighting: the shader modifier does the shading itself.
        material.lightingModel = .constant
        material.diffuse.contents = color(hex: hex)
        material.shaderModifiers = [.surface: MascotToon.surfaceModifier]
        return material
    }

    private static func makeOutlineMaterial() -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = NSColor(
            srgbRed: CGFloat(MascotToon.outlineColor.red), green: CGFloat(MascotToon.outlineColor.green),
            blue: CGFloat(MascotToon.outlineColor.blue), alpha: 1)
        // Cull the front so that only the inflated back faces rim the real mesh.
        material.cullMode = .front
        material.shaderModifiers = [.geometry: MascotToon.outlineGeometryModifier]
        return material
    }

    private static func makeShadow() -> SCNNode {
        let disc = SCNCylinder(radius: CGFloat(shadowRadius), height: 0.002)
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = NSColor(srgbRed: 0.17, green: 0.16, blue: 0.2, alpha: 1)
        material.transparency = CGFloat(shadowOpacity)
        material.writesToDepthBuffer = false
        disc.firstMaterial = material
        let node = SCNNode(geometry: disc)
        node.position.y = 0.001
        return node
    }

    private static func makeCamera() -> SCNNode {
        let camera = SCNCamera()
        camera.fieldOfView = CGFloat(verticalFieldOfView)
        camera.zNear = 0.1
        camera.zFar = 50
        let node = SCNNode()
        node.camera = camera
        node.position = SCNVector3(CGFloat(cameraPosition.x), CGFloat(cameraPosition.y), CGFloat(cameraPosition.z))
        // Looks down -Z by default; a negative turn about X tilts it toward the target.
        let drop = cameraPosition.y - cameraTarget.y
        node.eulerAngles.x = CGFloat(-atan2(drop, cameraPosition.z - cameraTarget.z))
        return node
    }
}
