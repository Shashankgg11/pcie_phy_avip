`ifndef PCIE_PHY_RC_AGENT_INCLUDED_
`define PCIE_PHY_RC_AGENT_INCLUDED_

//--------------------------------------------------------------------------------------------
// Class: pcie_phy_rc_agent
// Configurable agent for the Downstream Port (Root Complex): creates active/passive
// components (ltssm_sequencer, driver_proxy, monitor_proxy, coverage) for PCIe Gen6 PHY
//--------------------------------------------------------------------------------------------
class pcie_phy_rc_agent extends uvm_agent;
  `uvm_component_utils(pcie_phy_rc_agent)

  //Variable: pcie_phy_rc_agent_cfg_h
  pcie_phy_rc_agent_config pcie_phy_rc_agent_cfg_h;

  //Variable: pcie_phy_rc_ltssm_seqr_h
  pcie_phy_rc_ltssm_sequencer pcie_phy_rc_ltssm_seqr_h;

  //Variable: pcie_phy_rc_drv_proxy_h
  pcie_phy_rc_driver_proxy pcie_phy_rc_drv_proxy_h;

  //Variable: pcie_phy_rc_mon_proxy_h
  pcie_phy_rc_monitor_proxy pcie_phy_rc_mon_proxy_h;

  //Variable: pcie_phy_rc_cov_h
  pcie_phy_rc_coverage pcie_phy_rc_cov_h;

  //-------------------------------------------------------
  // Externally defined Tasks and Functions
  //-------------------------------------------------------
  extern function new(string name = "pcie_phy_rc_agent", uvm_component parent = null);
  extern virtual function void build_phase(uvm_phase phase);
  extern virtual function void connect_phase(uvm_phase phase);

endclass : pcie_phy_rc_agent

//--------------------------------------------------------------------------------------------
// Construct: new
// Initializes class object
//
// Parameters:
//  name - pcie_phy_rc_agent
//  parent - parent under which this component is created
//--------------------------------------------------------------------------------------------
function pcie_phy_rc_agent::new(string name = "pcie_phy_rc_agent", uvm_component parent = null);
  super.new(name, parent);
endfunction : new

//--------------------------------------------------------------------------------------------
// Function: build_phase
// <Description_here>
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------
function void pcie_phy_rc_agent::build_phase(uvm_phase phase);
  super.build_phase(phase);

  if (pcie_phy_rc_agent_cfg_h.is_active == UVM_ACTIVE) begin
    pcie_phy_rc_drv_proxy_h = pcie_phy_rc_driver_proxy::type_id::create("pcie_phy_rc_drv_proxy_h", this);
    pcie_phy_rc_ltssm_seqr_h = pcie_phy_rc_ltssm_sequencer::type_id::create("pcie_phy_rc_ltssm_seqr_h", this);
  end

  pcie_phy_rc_mon_proxy_h = pcie_phy_rc_monitor_proxy::type_id::create("pcie_phy_rc_mon_proxy_h", this);

  if (pcie_phy_rc_agent_cfg_h.has_coverage) begin
    pcie_phy_rc_cov_h = pcie_phy_rc_coverage::type_id::create("pcie_phy_rc_cov_h", this);
  end
endfunction : build_phase

//--------------------------------------------------------------------------------------------
// Function: connect_phase
// <Description_here>
//
// Parameters:
//  phase - uvm phase
//--------------------------------------------------------------------------------------------
function void pcie_phy_rc_agent::connect_phase(uvm_phase phase);
  super.connect_phase(phase);

  if (pcie_phy_rc_agent_cfg_h.is_active == UVM_ACTIVE) begin
    pcie_phy_rc_drv_proxy_h.pcie_phy_rc_agent_cfg_h = pcie_phy_rc_agent_cfg_h;
    pcie_phy_rc_ltssm_seqr_h.pcie_phy_rc_agent_cfg_h = pcie_phy_rc_agent_cfg_h;
    pcie_phy_rc_drv_proxy_h.seq_item_port.connect(pcie_phy_rc_ltssm_seqr_h.seq_item_export);
  end

  if (pcie_phy_rc_agent_cfg_h.has_coverage) begin
    pcie_phy_rc_cov_h.pcie_phy_rc_agent_cfg_h = pcie_phy_rc_agent_cfg_h;
    pcie_phy_rc_mon_proxy_h.ltssm_state_analysis_port.connect(pcie_phy_rc_cov_h.analysis_export);
  end

  pcie_phy_rc_mon_proxy_h.pcie_phy_rc_agent_cfg_h = pcie_phy_rc_agent_cfg_h;
endfunction : connect_phase


`endif
