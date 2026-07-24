`ifndef PCIE_PHY_IF_INCLUDED_
`define PCIE_PHY_IF_INCLUDED_
 
//--------------------------------------------------------------------------------------------
// Import pcie_phy_pkg
import pcie_phy_pkg::*;
//--------------------------------------------------------------------------------------------
 
 
//--------------------------------------------------------------------------------------------
// Interface: pcie_phy_intf
// Declaration of pin-level signals for the PCIe PHY link 
//--------------------------------------------------------------------------------------------
 
interface pcie_phy_intf(input logic pclk , input logic preset_n);
 
   logic [PCIE_MAX_LANES-1:0] TX_P;
   logic [PCIE_MAX_LANES-1:0] TX_N;
 
   logic [PCIE_MAX_LANES-1:0] RX_P;
   logic [PCIE_MAX_LANES-1:0] RX_N;
 
endinterface : pcie_phy_intf
 
`endif
