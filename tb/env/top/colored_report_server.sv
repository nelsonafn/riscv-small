//------------------------------------------------------------------------------
// Colored Report Server for UVM
//------------------------------------------------------------------------------
// This class overrides the default UVM report server to add ANSI colors 
// based on the severity of the message.
//
// Author: Nelson Alves nelsonafn@gmail.com
// Date  : April 2024
//------------------------------------------------------------------------------

`ifndef COLORED_REPORT_SERVER_SV
`define COLORED_REPORT_SERVER_SV

class colored_report_server extends uvm_default_report_server;

  /*
   * Constructor
   */
  function new(string name = "colored_report_server");
    super.new(name);
  endfunction : new

  /*
   * Function: compose_report_message
   * Overrides the default message formatting to include ANSI color codes.
   */
  virtual function string compose_report_message(uvm_report_message report_message, 
                                                 string report_object_name = "");
    string sev_str;
    string msg;
    string time_str;
    string color_start, color_end;
    string file_line_str = "";
    uvm_severity  severity;
    int           verbosity;
    
    // Procedural statements start here
    severity  = report_message.get_severity();
    verbosity = report_message.get_verbosity();
    msg       = report_message.get_message();
    sev_str   = severity.name();
    
    // Default color end (Reset)
    color_end = "\033[0m";

    // Set start color based on severity
    case(severity)
      UVM_INFO:    color_start = "\033[0;32m"; // Green
      UVM_WARNING: color_start = "\033[0;33m"; // Yellow
      UVM_ERROR:   color_start = "\033[0;31m"; // Red
      UVM_FATAL:   color_start = "\033[1;31;47m"; // Bold Red with Grey BG
      default:     color_start = "";
    endcase

    // Check if color should be disabled via plusarg
    if ($test$plusargs("NO_COLOR")) begin
      color_start = "";
      color_end   = "";
    end

    // Formatting timestamp
    $sformat(time_str, "%0t", $time);

    // Only show FILE(LINE) for critical errors or highly verbose debug messages
    if (severity >= UVM_ERROR || verbosity >= UVM_FULL || $test$plusargs("UVM_VERBOSITY=UVM_FULL")) begin
      file_line_str = $sformatf(" | %s", $sformatf("%s(%0d)", report_message.get_filename(), report_message.get_line()));
    end

    // Construct the final string: SEVERITY @ TIME [| FILE(LINE)] | [ID] MESSAGE
    return $sformatf("%s%-12s%s [%-14s]: %s | @ %s%s", 
                     color_start, sev_str, color_end, 
                     report_message.get_id(), 
                     msg,
                     time_str, 
                     file_line_str);
  endfunction : compose_report_message

endclass : colored_report_server

`endif
