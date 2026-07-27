#if hasFeature(Embedded)
import COpenCoreGraphicsSupport

public func sin(_ value: Double) -> Double { ocg_sin(value) }
public func cos(_ value: Double) -> Double { ocg_cos(value) }
public func tan(_ value: Double) -> Double { ocg_tan(value) }
public func atan2(_ y: Double, _ x: Double) -> Double { ocg_atan2(y, x) }
public func sqrt(_ value: Double) -> Double { ocg_sqrt(value) }
public func hypot(_ x: Double, _ y: Double) -> Double { ocg_hypot(x, y) }
public func pow(_ base: Double, _ exponent: Double) -> Double { ocg_pow(base, exponent) }
public func exp(_ value: Double) -> Double { ocg_exp(value) }
public func log(_ value: Double) -> Double { ocg_log(value) }
public func log2(_ value: Double) -> Double { ocg_log2(value) }
public func log10(_ value: Double) -> Double { ocg_log10(value) }
public func acos(_ value: Double) -> Double { ocg_acos(value) }
public func floor(_ value: Double) -> Double { ocg_floor(value) }
public func ceil(_ value: Double) -> Double { ocg_ceil(value) }

public func sin(_ value: Float) -> Float { Float(ocg_sin(Double(value))) }
public func cos(_ value: Float) -> Float { Float(ocg_cos(Double(value))) }
public func tan(_ value: Float) -> Float { Float(ocg_tan(Double(value))) }
public func atan2(_ y: Float, _ x: Float) -> Float { Float(ocg_atan2(Double(y), Double(x))) }
public func sqrt(_ value: Float) -> Float { Float(ocg_sqrt(Double(value))) }
public func hypot(_ x: Float, _ y: Float) -> Float { Float(ocg_hypot(Double(x), Double(y))) }
public func pow(_ base: Float, _ exponent: Float) -> Float {
    Float(ocg_pow(Double(base), Double(exponent)))
}
public func exp(_ value: Float) -> Float { Float(ocg_exp(Double(value))) }
public func log(_ value: Float) -> Float { Float(ocg_log(Double(value))) }
public func log2(_ value: Float) -> Float { Float(ocg_log2(Double(value))) }
public func log10(_ value: Float) -> Float { Float(ocg_log10(Double(value))) }
public func acos(_ value: Float) -> Float { Float(ocg_acos(Double(value))) }
public func floor(_ value: Float) -> Float { Float(ocg_floor(Double(value))) }
public func ceil(_ value: Float) -> Float { Float(ocg_ceil(Double(value))) }
#endif
