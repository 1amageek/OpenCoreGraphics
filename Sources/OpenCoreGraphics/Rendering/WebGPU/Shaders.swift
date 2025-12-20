//
//  Shaders.swift
//  CGWebGPU
//
//  WGSL shader code for 2D rendering
//

#if arch(wasm32)

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

    /// Texture shader for image rendering
    public static let texture2D: String = """
        struct VertexInput {
            @location(0) position: vec2f,
            @location(1) texCoord: vec2f,
        }

        struct VertexOutput {
            @builtin(position) position: vec4f,
            @location(0) texCoord: vec2f,
        }

        struct ImageUniforms {
            alpha: f32,
            _padding: vec3f,
        }

        @group(0) @binding(0) var textureSampler: sampler;
        @group(0) @binding(1) var textureData: texture_2d<f32>;
        @group(0) @binding(2) var<uniform> uniforms: ImageUniforms;

        @vertex
        fn vs_main(input: VertexInput) -> VertexOutput {
            var output: VertexOutput;
            output.position = vec4f(input.position, 0.0, 1.0);
            output.texCoord = input.texCoord;
            return output;
        }

        @fragment
        fn fs_main(input: VertexOutput) -> @location(0) vec4f {
            let color = textureSample(textureData, textureSampler, input.texCoord);
            return vec4f(color.rgb, color.a * uniforms.alpha);
        }
        """

    /// Gaussian blur shader (horizontal pass)
    /// Uses separable Gaussian blur for efficiency
    public static let blurHorizontal: String = """
        struct VertexOutput {
            @builtin(position) position: vec4f,
            @location(0) texCoord: vec2f,
        }

        struct BlurUniforms {
            texelSize: vec2f,  // 1.0 / textureSize
            blurRadius: f32,
            _padding: f32,
        }

        @group(0) @binding(0) var textureSampler: sampler;
        @group(0) @binding(1) var inputTexture: texture_2d<f32>;
        @group(0) @binding(2) var<uniform> uniforms: BlurUniforms;

        @vertex
        fn vs_main(@builtin(vertex_index) vertexIndex: u32) -> VertexOutput {
            // Full-screen quad
            var positions = array<vec2f, 6>(
                vec2f(-1.0, -1.0),
                vec2f( 1.0, -1.0),
                vec2f( 1.0,  1.0),
                vec2f(-1.0, -1.0),
                vec2f( 1.0,  1.0),
                vec2f(-1.0,  1.0)
            );
            var texCoords = array<vec2f, 6>(
                vec2f(0.0, 1.0),
                vec2f(1.0, 1.0),
                vec2f(1.0, 0.0),
                vec2f(0.0, 1.0),
                vec2f(1.0, 0.0),
                vec2f(0.0, 0.0)
            );

            var output: VertexOutput;
            output.position = vec4f(positions[vertexIndex], 0.0, 1.0);
            output.texCoord = texCoords[vertexIndex];
            return output;
        }

        @fragment
        fn fs_main(input: VertexOutput) -> @location(0) vec4f {
            var result = vec4f(0.0);
            var totalWeight = 0.0;

            let radius = i32(uniforms.blurRadius);
            let sigma = uniforms.blurRadius / 3.0;

            for (var i = -radius; i <= radius; i++) {
                let offset = vec2f(f32(i) * uniforms.texelSize.x, 0.0);
                let weight = exp(-f32(i * i) / (2.0 * sigma * sigma));
                result += textureSample(inputTexture, textureSampler, input.texCoord + offset) * weight;
                totalWeight += weight;
            }

            return result / totalWeight;
        }
        """

    /// Gaussian blur shader (vertical pass)
    public static let blurVertical: String = """
        struct VertexOutput {
            @builtin(position) position: vec4f,
            @location(0) texCoord: vec2f,
        }

        struct BlurUniforms {
            texelSize: vec2f,
            blurRadius: f32,
            _padding: f32,
        }

        @group(0) @binding(0) var textureSampler: sampler;
        @group(0) @binding(1) var inputTexture: texture_2d<f32>;
        @group(0) @binding(2) var<uniform> uniforms: BlurUniforms;

        @vertex
        fn vs_main(@builtin(vertex_index) vertexIndex: u32) -> VertexOutput {
            var positions = array<vec2f, 6>(
                vec2f(-1.0, -1.0),
                vec2f( 1.0, -1.0),
                vec2f( 1.0,  1.0),
                vec2f(-1.0, -1.0),
                vec2f( 1.0,  1.0),
                vec2f(-1.0,  1.0)
            );
            var texCoords = array<vec2f, 6>(
                vec2f(0.0, 1.0),
                vec2f(1.0, 1.0),
                vec2f(1.0, 0.0),
                vec2f(0.0, 1.0),
                vec2f(1.0, 0.0),
                vec2f(0.0, 0.0)
            );

            var output: VertexOutput;
            output.position = vec4f(positions[vertexIndex], 0.0, 1.0);
            output.texCoord = texCoords[vertexIndex];
            return output;
        }

        @fragment
        fn fs_main(input: VertexOutput) -> @location(0) vec4f {
            var result = vec4f(0.0);
            var totalWeight = 0.0;

            let radius = i32(uniforms.blurRadius);
            let sigma = uniforms.blurRadius / 3.0;

            for (var i = -radius; i <= radius; i++) {
                let offset = vec2f(0.0, f32(i) * uniforms.texelSize.y);
                let weight = exp(-f32(i * i) / (2.0 * sigma * sigma));
                result += textureSample(inputTexture, textureSampler, input.texCoord + offset) * weight;
                totalWeight += weight;
            }

            return result / totalWeight;
        }
        """

    /// Pattern tiling shader - repeats a pattern based on step values
    public static let patternTiling: String = """
        struct VertexInput {
            @location(0) position: vec2f,
            @location(1) color: vec4f,
        }

        struct VertexOutput {
            @builtin(position) position: vec4f,
            @location(0) worldPos: vec2f,
            @location(1) color: vec4f,
        }

        struct PatternUniforms {
            bounds: vec4f,        // x, y, width, height
            step: vec2f,          // xStep, yStep
            isColored: f32,       // 1.0 if colored, 0.0 if uncolored
            patternType: f32,     // 0=solid, 1=checkerboard, 2=stripes, 3=dots
        }

        @group(0) @binding(0) var<uniform> pattern: PatternUniforms;

        @vertex
        fn vs_main(input: VertexInput) -> VertexOutput {
            var output: VertexOutput;
            output.position = vec4f(input.position, 0.0, 1.0);
            output.worldPos = input.position;
            output.color = input.color;
            return output;
        }

        @fragment
        fn fs_main(input: VertexOutput) -> @location(0) vec4f {
            // Calculate pattern cell coordinates
            let cellX = input.worldPos.x / pattern.step.x;
            let cellY = input.worldPos.y / pattern.step.y;

            // Get position within cell (0 to 1)
            let inCellX = fract(cellX);
            let inCellY = fract(cellY);

            // Cell indices (for checkerboard pattern)
            let cellIdxX = i32(floor(cellX));
            let cellIdxY = i32(floor(cellY));

            var alpha = 1.0;

            // Pattern type processing
            let patternType = i32(pattern.patternType);

            if (patternType == 1) {
                // Checkerboard pattern
                if ((cellIdxX + cellIdxY) % 2 == 0) {
                    alpha = 1.0;
                } else {
                    alpha = 0.3;
                }
            } else if (patternType == 2) {
                // Horizontal stripes
                if (inCellY < 0.5) {
                    alpha = 1.0;
                } else {
                    alpha = 0.3;
                }
            } else if (patternType == 3) {
                // Dots pattern
                let center = vec2f(0.5, 0.5);
                let dist = length(vec2f(inCellX, inCellY) - center);
                if (dist < 0.3) {
                    alpha = 1.0;
                } else {
                    alpha = 0.0;
                }
            }
            // else: solid pattern (patternType == 0), alpha = 1.0

            // Apply color
            if (pattern.isColored > 0.5) {
                // Colored pattern - use pattern's own color (gray placeholder)
                return vec4f(0.5, 0.5, 0.5, alpha);
            } else {
                // Uncolored pattern - use input color with pattern alpha
                return vec4f(input.color.rgb, input.color.a * alpha);
            }
        }
        """

    /// Shadow composite shader - draws shadow with offset and color tint
    public static let shadowComposite: String = """
        struct VertexOutput {
            @builtin(position) position: vec4f,
            @location(0) texCoord: vec2f,
        }

        struct ShadowUniforms {
            shadowColor: vec4f,
            offset: vec2f,       // Normalized offset
            _padding: vec2f,
        }

        @group(0) @binding(0) var textureSampler: sampler;
        @group(0) @binding(1) var shadowTexture: texture_2d<f32>;
        @group(0) @binding(2) var<uniform> uniforms: ShadowUniforms;

        @vertex
        fn vs_main(@builtin(vertex_index) vertexIndex: u32) -> VertexOutput {
            var positions = array<vec2f, 6>(
                vec2f(-1.0, -1.0),
                vec2f( 1.0, -1.0),
                vec2f( 1.0,  1.0),
                vec2f(-1.0, -1.0),
                vec2f( 1.0,  1.0),
                vec2f(-1.0,  1.0)
            );
            var texCoords = array<vec2f, 6>(
                vec2f(0.0, 1.0),
                vec2f(1.0, 1.0),
                vec2f(1.0, 0.0),
                vec2f(0.0, 1.0),
                vec2f(1.0, 0.0),
                vec2f(0.0, 0.0)
            );

            var output: VertexOutput;
            output.position = vec4f(positions[vertexIndex], 0.0, 1.0);
            output.texCoord = texCoords[vertexIndex];
            return output;
        }

        @fragment
        fn fs_main(input: VertexOutput) -> @location(0) vec4f {
            // Sample shadow texture with offset
            let shadowAlpha = textureSample(shadowTexture, textureSampler, input.texCoord - uniforms.offset).a;

            // Apply shadow color with sampled alpha
            return vec4f(uniforms.shadowColor.rgb, uniforms.shadowColor.a * shadowAlpha);
        }
        """
}

#endif
