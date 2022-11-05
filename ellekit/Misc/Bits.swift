
func reverse(_ base: Int) -> Int {
    ((base>>24)&0xff) | ((base<<8)&0xff0000) | ((base>>8)&0xff00) | ((base<<24)&0xff000000)
}

func encodeOperand(_ val: Int) -> Int {
    if !(val != val & 0xFFFFFFFF) {
        for offset in 0..<32 {
            if (ror(val, offset) <= 0xFF) {
                return ror(val, offset) | (16 - offset / 2) % 16 << 8
            }
        }
    }
    return 0
}

// thanks @jsherman212 for tdhe bitwise functions from armadillo
// i was very confused as to how to detect a branch instruction
func bits(_ target: UInt64, _ start: UInt64, _ end: UInt64) -> UInt64 {
    let amount: UInt64 = (end - start) + 1;
    let mask: UInt64 = ((1 << amount) - 1) << start;

    return (target & mask) >> start
}

func sign_extend(_ number: Int, _ numbits: Int) -> Int {
    if (number & (1 << (numbits - 1))) == 1 {
        return number | ~((1 << numbits) - 1);
    }
    return number;
}
