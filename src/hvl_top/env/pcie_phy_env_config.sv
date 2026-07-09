`ifndef PCIE_PHY_ENV_CONFIG_INCLUDED_
`define PCIE_PHY_ENV_CONFIG_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: pcie_phy_env_config
// Used as the configuration class for the environment and its components
//--------------------------------------------------------------------------------------------
class pcie_phy_env_config extends uvm_object;
  `uvm_object_utils(pcie_phy_env_config)

  //Variable: has_scoreboard
  bit has_scoreboard = 1;

  //Variable: has_virtual_seqr
  bit has_virtual_seqr = 1;

  //Variable: no_of_rc
  int no_of_rc = 1;

  //Variable: no_of_ep
  int no_of_ep = 1;

  //Variable: pcie_phy_rc_agent_cfg_h
  pcie_phy_rc_agent_config pcie_phy_rc_agent_cfg_h[];

  //Variable: pcie_phy_ep_agent_cfg_h
  pcie_phy_ep_agent_config pcie_phy_ep_agent_cfg_h[];

  //-------------------------------------------------------
  // Externally defined Tasks and Functions
  //-------------------------------------------------------
  extern function new(string name = "pcie_phy_env_config");

endclass : pcie_phy_env_config

//--------------------------------------------------------------------------------------------
// Construct: new
// Initializes class object
//
// Parameters:
//  name - pcie_phy_env_config
//--------------------------------------------------------------------------------------------
function pcie_phy_env_config::new(string name = "pcie_phy_env_config");
  super.new(name);
endfunction : new


`endif
