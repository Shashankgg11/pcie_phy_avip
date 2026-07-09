`ifndef PCIE_PHY_RC_CFG_CONVERTER_INCLUDED_
`define PCIE_PHY_RC_CFG_CONVERTER_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: pcie_phy_rc_cfg_converter
// Converts rc agent config fields into the BFM-side config struct
//--------------------------------------------------------------------------------------------
class pcie_phy_rc_cfg_converter extends uvm_object;
  `uvm_object_utils(pcie_phy_rc_cfg_converter)

  //-------------------------------------------------------
  // Externally defined Tasks and Functions
  //-------------------------------------------------------
  extern function new(string name = "pcie_phy_rc_cfg_converter");
  extern virtual function void convert_agent_cfg_to_bfm(pcie_phy_rc_agent_config cfg, ref pcie_phy_bfm_cfg_s bfm_cfg);

endclass : pcie_phy_rc_cfg_converter

//--------------------------------------------------------------------------------------------
// Construct: new
// Initializes class object
//
// Parameters:
//  name - pcie_phy_rc_cfg_converter
//--------------------------------------------------------------------------------------------
function pcie_phy_rc_cfg_converter::new(string name = "pcie_phy_rc_cfg_converter");
  super.new(name);
endfunction : new

//--------------------------------------------------------------------------------------------
// Function: convert_agent_cfg_to_bfm
// <Description_here> — packs agent_config fields into the BFM-side cfg struct
//
// Parameters:
//  cfg - agent config
//  bfm_cfg - BFM cfg struct (by ref)
//--------------------------------------------------------------------------------------------
function void pcie_phy_rc_cfg_converter::convert_agent_cfg_to_bfm(pcie_phy_rc_agent_config cfg, ref pcie_phy_bfm_cfg_s bfm_cfg);
  // TODO: field-by-field conversion
endfunction : convert_agent_cfg_to_bfm


`endif
