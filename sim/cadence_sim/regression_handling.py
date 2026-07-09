#!/usr/bin/env python3
"""
cadence regression runner — pcie_phy_avip
Auto-generated skeleton
"""

TESTLIST = "../../src/hvl_top/testlists/pcie_phy_regression.list"


def main():
    with open(TESTLIST) as f:
        tests = [l.strip() for l in f if l.strip() and not l.startswith("#")]
    for t in tests:
        print(f"TODO: launch {t} on cadence")


if __name__ == "__main__":
    main()
