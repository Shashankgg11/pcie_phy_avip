`ifndef HDL_TOP_INCLUDED_
`define HDL_TOP_INCLUDED_

//--------------------------------------------------------------------------------------------
// Module: HDL Top
// Instantiates two pcie_phy_if ports (rc_intf, ep_intf) direct-connected to each other,
// and the rc/ep agent BFMs bound to them.
//--------------------------------------------------------------------------------------------
module hdl_top;

  import uvm_pkg::*;
  import pcie_phy_pkg::*;
  `include "uvm_macros.svh"

  //-------------------------------------------------------
  // Clock / Reset
  //-------------------------------------------------------
  bit pclk;
  bit preset_n;

  initial begin
    $display("HDL_TOP");
  end

  initial begin
    pclk = 1'b0;
    forever #10 pclk = ~pclk;
  end

  initial begin
    preset_n = 1'b1;
    #10 preset_n = 1'b0;
    repeat(1) @(posedge pclk);
    preset_n = 1'b1;
  end

  initial begin
    $dumpfile("waveform.vcd");
    $dumpvars(0, hdl_top);
  end

  //-------------------------------------------------------
  // RC / EP port interface instances
  //-------------------------------------------------------

pcie_phy_if rc_intf(
    .pclk(pclk),
    .preset_n(preset_n)
);
pcie_phy_if ep_intf(
    .pclk(pclk),
    .preset_n(preset_n)
);
  

  //-------------------------------------------------------
  // Direct-connect cross-wiring: each port's RX is the partner's TX
  //-------------------------------------------------------
  assign rc_intf.RX_P = ep_intf.TX_P;
  assign rc_intf.RX_N = ep_intf.TX_N;
  assign ep_intf.RX_P = rc_intf.TX_P;
  assign ep_intf.RX_N = rc_intf.TX_N;
 
  //-------------------------------------------------------
  // RC / EP Agent BFM Instantiation
  //-------------------------------------------------------
  pcie_phy_rc_agent_bfm #(.RC_ID(0)) pcie_phy_rc_agent_bfm_h (rc_intf);
  pcie_phy_ep_agent_bfm #(.EP_ID(0)) pcie_phy_ep_agent_bfm_h (ep_intf);

endmodule : hdl_top

`endif
