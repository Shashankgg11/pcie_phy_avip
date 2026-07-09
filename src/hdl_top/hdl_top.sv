`ifndef HDL_TOP_INCLUDED_
`define HDL_TOP_INCLUDED_

//--------------------------------------------------------------------------------------------
// Module: HDL Top
// Instantiates the pcie_phy_if and the rc/ep agent BFMs
//--------------------------------------------------------------------------------------------
module hdl_top;

  import uvm_pkg::*;
  import pcie_phy_globals_pkg::*;
  `include "uvm_macros.svh"

  //-------------------------------------------------------
  // Clock / Reset
  //-------------------------------------------------------
  bit aclk;
  bit aresetn;

  initial begin
    $display("HDL_TOP");
  end

  initial begin
    aclk = 1'b0;
    forever #10 aclk = ~aclk;
  end

  initial begin
    aresetn = 1'b1;
    #10 aresetn = 1'b0;
    repeat(1) @(posedge aclk);
    aresetn = 1'b1;
  end

  initial begin
    $dumpfile("waveform.vcd");
    $dumpvars(0, hdl_top);
  end

  //Variable: intf
  //pcie_phy Interface Instantiation
  pcie_phy_if intf(.aclk(aclk), .aresetn(aresetn));

  //-------------------------------------------------------
  // RC / EP Agent BFM Instantiation
  //-------------------------------------------------------
  pcie_phy_rc_agent_bfm #(.RC_ID(0)) pcie_phy_rc_agent_bfm_h (intf);
  pcie_phy_ep_agent_bfm #(.EP_ID(0)) pcie_phy_ep_agent_bfm_h (intf);

endmodule : hdl_top

`endif
