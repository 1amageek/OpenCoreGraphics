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

    /// Per-vertex color shader with continuous image-mask clip coverage.
    public static let maskedSimple2D: String = """
        struct VertexInput {
            @location(0) position: vec2f,
            @location(1) color: vec4f,
        }

        struct VertexOutput {
            @builtin(position) position: vec4f,
            @location(0) color: vec4f,
        }

        @group(0) @binding(0) var clipMask: texture_2d<f32>;

        @vertex
        fn vs_main(input: VertexInput) -> VertexOutput {
            var output: VertexOutput;
            output.position = vec4f(input.position, 0.0, 1.0);
            output.color = input.color;
            return output;
        }

        @fragment
        fn fs_main(input: VertexOutput) -> @location(0) vec4f {
            let coverage = textureLoad(clipMask, vec2i(input.position.xy), 0).r;
            return vec4f(input.color.rgb, input.color.a * coverage);
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

    /// Image shader with continuous image-mask clip coverage.
    public static let maskedTexture2D: String = """
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
        @group(0) @binding(1) var imageTexture: texture_2d<f32>;
        @group(0) @binding(2) var<uniform> uniforms: ImageUniforms;
        @group(1) @binding(0) var clipMask: texture_2d<f32>;

        @vertex
        fn vs_main(input: VertexInput) -> VertexOutput {
            var output: VertexOutput;
            output.position = vec4f(input.position, 0.0, 1.0);
            output.texCoord = input.texCoord;
            return output;
        }

        @fragment
        fn fs_main(input: VertexOutput) -> @location(0) vec4f {
            let color = textureSample(imageTexture, textureSampler, input.texCoord);
            let coverage = textureLoad(clipMask, vec2i(input.position.xy), 0).r;
            return vec4f(color.rgb, color.a * uniforms.alpha * coverage);
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

    /// Pattern tiling shader backed by the pattern callback's rendered cell.
    public static let patternTiling: String = """
        struct VertexInput {
            @location(0) position: vec2f,
            @location(1) color: vec4f,
        }

        struct VertexOutput {
            @builtin(position) position: vec4f,
            @location(0) devicePosition: vec2f,
            @location(1) color: vec4f,
        }

        struct PatternUniforms {
            inverseLinear: vec4f,
            inverseTranslation: vec2f,
            viewportSize: vec2f,
            bounds: vec4f,
            step: vec2f,
            alpha: f32,
            isColored: f32,
        }

        @group(0) @binding(0) var patternSampler: sampler;
        @group(0) @binding(1) var patternCell: texture_2d<f32>;
        @group(0) @binding(2) var<uniform> pattern: PatternUniforms;
        @group(1) @binding(0) var clipMask: texture_2d<f32>;

        @vertex
        fn vs_main(input: VertexInput) -> VertexOutput {
            var output: VertexOutput;
            output.position = vec4f(input.position, 0.0, 1.0);
            output.devicePosition = vec2f(
                (input.position.x + 1.0) * 0.5 * pattern.viewportSize.x,
                (input.position.y + 1.0) * 0.5 * pattern.viewportSize.y
            );
            output.color = input.color;
            return output;
        }

        @fragment
        fn fs_main(input: VertexOutput) -> @location(0) vec4f {
            let devicePosition = input.devicePosition;
            let patternPosition = vec2f(
                pattern.inverseLinear.x * devicePosition.x + pattern.inverseLinear.z * devicePosition.y + pattern.inverseTranslation.x,
                pattern.inverseLinear.y * devicePosition.x + pattern.inverseLinear.w * devicePosition.y + pattern.inverseTranslation.y
            );
            let cellIndex = floor((patternPosition - pattern.bounds.xy) / pattern.step);
            let cellPosition = patternPosition - pattern.bounds.xy - cellIndex * pattern.step;
            let normalizedCellPosition = cellPosition / pattern.bounds.zw;

            if (normalizedCellPosition.x < 0.0 || normalizedCellPosition.x > 1.0 ||
                normalizedCellPosition.y < 0.0 || normalizedCellPosition.y > 1.0) {
                discard;
            }

            let textureCoordinate = vec2f(normalizedCellPosition.x, 1.0 - normalizedCellPosition.y);
            let cellColor = textureSample(patternCell, patternSampler, textureCoordinate);
            let coverage = textureLoad(clipMask, vec2i(input.position.xy), 0).r;

            if (pattern.isColored > 0.5) {
                return vec4f(cellColor.rgb, cellColor.a * pattern.alpha * coverage);
            } else {
                return vec4f(input.color.rgb, input.color.a * cellColor.a * pattern.alpha * coverage);
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
