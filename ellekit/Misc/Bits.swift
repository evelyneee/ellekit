
func reverse<T: FixedWidthInteger>(_ base: T) -> T {
    ((base>>24)&0xff) | ((base<<8)&0xff0000) | ((base>>8)&0xff00) | ((base<<24)&0xff000000)
}

extension FixedWidthInteger {
    func bits(_ range: ClosedRange<Self>) -> Self {
        let amount: Self = (range.upperBound - range.lowerBound) + 1;
        let mask: Self = ((1 << amount) - 1) << range.lowerBound;

        return (self & mask) >> range.lowerBound
    }
}
