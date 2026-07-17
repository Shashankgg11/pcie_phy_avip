//EP_TX
 
`ifndef PCIE_PHY_EP_TX_INCLUDED_

`define PCIE_PHY_EP_TX_INCLUDED_
 
//--------------------------------------------------------------------------------------------

// Class: pcie_phy_ep_tx

// This class holds the data items required to drive PHY directives

// to the Upstream Port (Endpoint) LTSSM and also holds methods that manipulate those items.

//--------------------------------------------------------------------------------------------

class pcie_phy_ep_tx extends uvm_sequence_item;

  `uvm_object_utils(pcie_phy_ep_tx)
 
  pcie_phy_ep_agent_config pcie_phy_ep_agent_cfg_h;
 
  //Variable: target_state

  rand ltssm_state_e target_state;
 
  //Variable: requested_gen

  // Uses pcie_gen_e directly since the package already models speed as

  // a proper enum (GEN1..GEN6) rather than a raw Sym4 hex value.

  rand pcie_gen_e requested_gen;
 
  //Variable: requested_width

  // Uses the package's link_width_e rather than a raw lane count.

  rand link_width_e requested_width;
 
  //Variable: l0p_request

  // Requests entry into L0p (partial-width low-power link state) once L0

  // is reached — EP-initiated in real PCIe, so this directive lives here

  // and not on the RC side. Only meaningful when target_state == L0_ST.

  rand bit l0p_request;
 
  // NOTE: an error-injection directive field (e.g. force sub-state

  // timeout, force symbol-lock loss) would normally live here, but the

  // enum type it needs (pcie_phy_error_inject_e) isn't defined in

  // pcie_phy_pkg yet. Left out rather than referencing an undefined

  // type — add once that enum exists in the package.
 
  //-------------------------------------------------------

  // Constraints

  //-------------------------------------------------------

  constraint c_default_gen {

    requested_gen == GEN6;

  }
 
  constraint c_default_width {

    requested_width == X4;

  }
 
  constraint c_l0p_only_at_l0 {

    l0p_request -> target_state == L0_ST;

  }
 
  //-------------------------------------------------------

  // Externally defined Tasks and Functions

  //-------------------------------------------------------

  extern function new(string name = "pcie_phy_ep_tx");

  extern virtual function void do_print(uvm_printer printer);
 
endclass : pcie_phy_ep_tx
 
//--------------------------------------------------------------------------------------------

// Construct: new

// Initializes class object

//

// Parameters:

//  name - pcie_phy_ep_tx

//--------------------------------------------------------------------------------------------

function pcie_phy_ep_tx::new(string name = "pcie_phy_ep_tx");

  super.new(name);

endfunction : new
 
//--------------------------------------------------------------------------------------------

// Function: do_print

// Prints every directive field so waveform-less log debug is possible.

//

// Parameters:

//  printer - uvm_printer

//--------------------------------------------------------------------------------------------

function void pcie_phy_ep_tx::do_print(uvm_printer printer);

  super.do_print(printer);

  printer.print_string("target_state",    target_state.name());

  printer.print_string("requested_gen",   requested_gen.name());

  printer.print_string("requested_width", requested_width.name());

  printer.print_field ("l0p_request",     l0p_request, 1);

endfunction : do_print
 
`endif
 
 
