import Foundation

/// Toon shading and outline for the mascot, kept in one place because the numbers
/// and the shader source need tuning on a real Mac (nothing here could be run
/// where it was written).
enum MascotToon {
    // MARK: Tunable numbers

    /// Brightness of the three flat steps, darkest to brightest.
    static let shadowBrightness = 0.59
    static let midBrightness = 0.84
    static let lightBrightness = 1.0
    /// N dot L above which a surface gets the next brighter step. The prototype's
    /// three-pixel gradient map puts them at +-1/3.
    static let midThreshold = -0.33
    static let lightThreshold = 0.33
    /// Direction toward the light in world space, as in the prototype's sun.
    static let lightDirection = (x: -3.0, y: 5.0, z: 4.0)
    /// Outline thickness in model units, pushed out along the normals.
    static let outlineWidth = 0.02
    static let outlineColor = (red: 0.16, green: 0.13, blue: 0.12)

    // MARK: Shader sources (Metal)

    /// Surface-stage modifier for a constant-lighting material: steps the flat
    /// colour by N dot L against one fixed light, so that no SceneKit light is
    /// needed. `_surface.normal` is in view space, hence the light is moved there.
    static var surfaceModifier: String {
        """
        float3 worldLight = normalize(float3(\(lightDirection.x), \(lightDirection.y), \(lightDirection.z)));
        float3 viewLight = normalize((scn_frame.viewTransform * float4(worldLight, 0.0)).xyz);
        float d = dot(normalize(_surface.normal), viewLight);
        float band = d > \(lightThreshold) ? \(lightBrightness) : (d > \(midThreshold) ? \(midBrightness) : \(shadowBrightness));
        _surface.diffuse.rgb *= band;
        """
    }

    /// Geometry-stage modifier for the inverted hull: the copy is front-face culled
    /// and inflated, so only a rim of it shows behind the real mesh.
    static var outlineGeometryModifier: String {
        """
        _geometry.position.xyz += _geometry.normal * \(outlineWidth);
        """
    }
}
