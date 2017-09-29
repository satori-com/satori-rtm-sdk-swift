
// Our internal stdlib

// The SDK code uses `not` function instead of bang so that the only meaning for
// a bang is unsafe optional unwrapping. This makes it possible to forbid the
// latter using just grep.
internal func not(_ cond: Bool) -> Bool {
    if cond {
        return false
    }
    return true
}

// Writing the same with a ternary operator is possible, but involves a bang.
// We're avoiding bangs.
internal func maybe<A, B>(_ z: B, _ f: (A) -> B, _ ma: A?) -> B {
    guard let a = ma else { return z }
    return f(a)
}