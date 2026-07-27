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
  // ref_clk : PCIe reference clock (100MHz-class, free-running, not used directly by the
  //           logical/bit-serial BFM tasks - present for pin-accuracy / future PLL modeling)
  // d_clk   : bit/UI clock the driver_bfm and monitor_bfm actually toggle on (1 bit-time per edge)
  // rst_n   : active-low reset, shared by both ports on a direct-connect link
  //-------------------------------------------------------
  bit ref_clk;
  bit d_clk;
  bit rst_n;

  initial begin
    $display("HDL_TOP");
  end

  initial begin
    ref_clk = 1'b0;
    forever #4 ref_clk = ~ref_clk; // 125MHz-ish reference, illustrative only
  end

  initial begin
    d_clk = 1'b0;
    forever #10 d_clk = ~d_clk;
  end

  initial begin
    rst_n = 1'b1;
    #10 rst_n = 1'b0;
    repeat(1) @(posedge d_clk);
    rst_n = 1'b1;
  end

  initial begin
    $dumpfile("waveform.vcd");
    $dumpvars(0, hdl_top);
  end

  //-------------------------------------------------------
  // RC / EP port interface instances
  //-------------------------------------------------------
  //Variable: rc_intf / ep_intf
  //Each pcie_phy_if instance is one port's own pin view (see pcie_phy_if.sv). Clock/reset
  //are plain internal nets on the interface (no port list), driven here from outside.
  pcie_phy_if rc_intf();
  pcie_phy_if ep_intf();

  assign rc_intf.ref_clk = ref_clk;
  assign rc_intf.d_clk   = d_clk;
  assign rc_intf.rst_n   = rst_n;

  assign ep_intf.ref_clk = ref_clk;
  assign ep_intf.d_clk   = d_clk;
  assign ep_intf.rst_n   = rst_n;

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
