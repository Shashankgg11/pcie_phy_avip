`ifndef PCIE_PHY_ENV_INCLUDED_
`define PCIE_PHY_ENV_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: pcie_phy_env
// Environment contains rc_agent, ep_agent, virtual_sequencer and scoreboard
//--------------------------------------------------------------------------------------------
class pcie_phy_env extends uvm_env;
  `uvm_component_utils(pcie_phy_env)

  //Variable: pcie_phy_env_cfg_h
  pcie_phy_env_config pcie_phy_env_cfg_h;

  //Variable: pcie_phy_rc_agent_h
  pcie_phy_rc_agent pcie_phy_rc_agent_h[];

  //Variable: pcie_phy_ep_agent_h
  pcie_phy_ep_agent pcie_phy_ep_agent_h[];

  //Variable: pcie_phy_virtual_seqr_h
  pcie_phy_virtual_sequencer pcie_phy_virtual_seqr_h;

  //Variable: pcie_phy_scoreboard_h
  pcie_phy_scoreboard pcie_phy_scoreboard_h;

  //-------------------------------------------------------
  // Externally defined Tasks and Functions
  //-------------------------------------------------------
  extern function new(string name = "pcie_phy_env", uvm_component parent = null);
  extern virtual function void build_phase(uvm_phase phase);
  extern virtual function void connect_phase(uvm_phase phase);

endclass : pcie_phy_env

//--------------------------------------------------------------------------------------------
// Construct: new
// Initializes class object
//
// Parameters:
//  name - pcie_phy_env
//  parent - parent under which this component is created
//--------------------------------------------------------------------------------------------
function pcie_phy_env::new(string name = "pcie_phy_env", uvm_component parent = null);
  super.new(name, parent);
endfunction : new

//--------------------------------------------------------------------------------------------
// Function: build_phase
// <Description_here>
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------
function void pcie_phy_env::build_phase(uvm_phase phase);
  super.build_phase(phase);

  pcie_phy_rc_agent_h = new[pcie_phy_env_cfg_h.no_of_rc];
  foreach (pcie_phy_rc_agent_h[i])
    pcie_phy_rc_agent_h[i] = pcie_phy_rc_agent::type_id::create($sformatf("pcie_phy_rc_agent_h[%0d]", i), this);

  pcie_phy_ep_agent_h = new[pcie_phy_env_cfg_h.no_of_ep];
  foreach (pcie_phy_ep_agent_h[i])
    pcie_phy_ep_agent_h[i] = pcie_phy_ep_agent::type_id::create($sformatf("pcie_phy_ep_agent_h[%0d]", i), this);

  if (pcie_phy_env_cfg_h.has_virtual_seqr)
    pcie_phy_virtual_seqr_h = pcie_phy_virtual_sequencer::type_id::create("pcie_phy_virtual_seqr_h", this);

  if (pcie_phy_env_cfg_h.has_scoreboard)
    pcie_phy_scoreboard_h = pcie_phy_scoreboard::type_id::create("pcie_phy_scoreboard_h", this);
endfunction : build_phase

//--------------------------------------------------------------------------------------------
// Function: connect_phase
// <Description_here>
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------
function void pcie_phy_env::connect_phase(uvm_phase phase);
  super.connect_phase(phase);

  if (pcie_phy_env_cfg_h.has_virtual_seqr) begin
    pcie_phy_virtual_seqr_h.pcie_phy_rc_ltssm_seqr_h = pcie_phy_rc_agent_h[0].pcie_phy_rc_ltssm_seqr_h;
    pcie_phy_virtual_seqr_h.pcie_phy_ep_ltssm_seqr_h = pcie_phy_ep_agent_h[0].pcie_phy_ep_ltssm_seqr_h;
  end

  if (pcie_phy_env_cfg_h.has_scoreboard) begin
    pcie_phy_rc_agent_h[0].pcie_phy_rc_mon_proxy_h.ltssm_state_analysis_port.connect(pcie_phy_scoreboard_h.pcie_phy_rc_analysis_export);
    pcie_phy_ep_agent_h[0].pcie_phy_ep_mon_proxy_h.ltssm_state_analysis_port.connect(pcie_phy_scoreboard_h.pcie_phy_ep_analysis_export);
  end
endfunction : connect_phase


`endif
