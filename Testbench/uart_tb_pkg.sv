//==============================================================================
// UART Testbench Package
// Bundles every class file into one package, in dependency order, so any
// module/file can get access to all of them with a single `import`.
//
// Note: `include is a textual copy-paste resolved at compile time - the
// files below are not "separately compiled modules", they're merged into
// this package's text before elaboration. Order matters: a file can't
// reference a class declared further down.
//==============================================================================

package uart_tb_pkg;

    import uart_pkg::*; // RTL-side package (calc_parity) - used by driver/monitor

    `include "transaction.sv"  // no dependencies
    `include "generator.sv"    // depends on: uart_transaction
    `include "driver.sv"       // depends on: uart_transaction, uart_pkg
    `include "monitor.sv"      // depends on: uart_transaction, uart_pkg
    `include "scoreboard.sv"   // depends on: uart_transaction
    `include "environment.sv"  // depends on: generator, driver, monitor, scoreboard
    `include "test.sv"         // depends on: environment

endpackage