//
//  Shaders.swift
//  CGWebGPU
//
//  WGSL shader code for 2D rendering
//

#if !canImport(CoreGraphics)

/// WGSL shaders for CoreGraphics-style 2D rendering
public enum CGWebGPUShaders {

    /// Basic 2D shader with per-vertex color
    /// Supports: solid fills, strokes with vertex colors
    public static let basic2D: String = """
        // Vertex input from CPU
        struct VertexInput {
            @location(0) position: vec2f,
            @location(1) color: vec4f,
        }

        // Vertex output to fragment shader
        struct VertexOutput {
            @builtin(position) position: vec4f,
            @location(0) color: vec4f,
        }

        // Uniforms for global transformations
        struct Uniforms {
            transform: mat3x3f,
            alpha: f32,
        }

        @group(0) @binding(0) var<uniform> uniforms: Uniforms;

        @vertex
        fn vs_main(input: VertexInput) -> VertexOutput {
            var output: VertexOutput;

            // Apply 2D transformation matrix
            let pos = uniforms.transform * vec3f(input.position, 1.0);
            output.position = vec4f(pos.xy, 0.0, 1.0);

            // Pass color with global alpha
            output.color = vec4f(input.color.rgb, input.color.a * uniforms.alpha);

            return output;
        }

        @fragment
        fn fs_main(input: VertexOutput) -> @location(0) vec4f {
            return input.color;
        }
        """

    /// Simple shader without uniforms (for testing)
    public static let simple2D: String = """
        struct VertexInput {
            @location(0) position: vec2f,
            @location(1) color: vec4f,
        }

        struct VertexOutput {
            @builtin(position) position: vec4f,
            @location(0) color: vec4f,
        }

        @vertex
        fn vs_main(input: VertexInput) -> VertexOutput {
            var output: VertexOutput;
            output.position = vec4f(input.position, 0.0, 1.0);
            output.color = input.color;
            return output;
        }

        @fragment
        fn fs_main(input: VertexOutput) -> @location(0) vec4f {
            return input.color;
        }
        """

    /// Gradient shader with linear interpolation
    public static let linearGradient: String = """
        struct VertexInput {
            @location(0) position: vec2f,
            @location(1) color: vec4f,
        }

        struct VertexOutput {
            @builtin(position) position: vec4f,
            @location(0) uv: vec2f,
        }

        struct GradientUniforms {
            startPoint: vec2f,
            endPoint: vec2f,
            startColor: vec4f,
            endColor: vec4f,
        }

        @group(0) @binding(0) var<uniform> gradient: GradientUniforms;

        @vertex
        fn vs_main(input: VertexInput) -> VertexOutput {
            var output: VertexOutput;
            output.position = vec4f(input.position, 0.0, 1.0);
            output.uv = input.position;
            return output;
        }

        @fragment
        fn fs_main(input: VertexOutput) -> @location(0) vec4f {
            let dir = gradient.endPoint - gradient.startPoint;
            let len = length(dir);
            if (len == 0.0) {
                return gradient.startColor;
            }

            let normalized = dir / len;
            let projected = dot(input.uv - gradient.startPoint, normalized);
            let t = clamp(projected / len, 0.0, 1.0);

            return mix(gradient.startColor, gradient.endColor, t);
        }
        """

    /// Radial gradient shader
    public static let radialGradient: String = """
        struct VertexInput {
            @location(0) position: vec2f,
            @location(1) color: vec4f,
        }

        struct VertexOutput {
            @builtin(position) position: vec4f,
            @location(0) uv: vec2f,
        }

        struct RadialGradientUniforms {
            center: vec2f,
            radius: f32,
            _padding: f32,
            startColor: vec4f,
            endColor: vec4f,
        }

        @group(0) @binding(0) var<uniform> gradient: RadialGradientUniforms;

        @vertex
        fn vs_main(input: VertexInput) -> VertexOutput {
            var output: VertexOutput;
            output.position = vec4f(input.position, 0.0, 1.0);
            output.uv = input.position;
            return output;
        }

        @fragment
        fn fs_main(input: VertexOutput) -> @location(0) vec4f {
            let dist = length(input.uv - gradient.center);
            let t = clamp(dist / gradient.radius, 0.0, 1.0);
            return mix(gradient.startColor, gradient.endColor, t);
        }
        """
}

#endif
