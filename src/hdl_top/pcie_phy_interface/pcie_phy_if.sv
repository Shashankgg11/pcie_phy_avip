`ifndef PCIE_PHY_IF_INCLUDED_
`define PCIE_PHY_IF_INCLUDED_
 
//--------------------------------------------------------------------------------------------
// Import pcie_phy_pkg
import pcie_phy_pkg::*;
//--------------------------------------------------------------------------------------------
 
 
//--------------------------------------------------------------------------------------------
// Interface: pcie_phy_intf
//--------------------------------------------------------------------------------------------
 
interface pcie_phy_if (input pclk, input preset_n);
 
  logic [PCIE_MAX_LANES-1:0] TX_P, TX_N;
  logic [PCIE_MAX_LANES-1:0] RX_P, RX_N;
 
endinterface : pcie_phy_if
 
`endif
