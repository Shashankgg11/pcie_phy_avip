//--------------------------------------------------------------------------------------------
// Module: HVL Top
// Imports UVM/test packages and starts the test
//--------------------------------------------------------------------------------------------
module hvl_top;

  import pcie_phy_test_pkg::*;
  import uvm_pkg::*;

  initial begin : START_TEST
    run_test("pcie_phy_base_test");
  end

endmodule : hvl_top
