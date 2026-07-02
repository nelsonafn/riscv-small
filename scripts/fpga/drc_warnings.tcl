# Pre-hook script to downgrade DRC severity for unconstrained ports,
# allowing bitstream generation without a physical constraints (XDC) file.
set_property SEVERITY {Warning} [get_drc_checks NSTD-1]
set_property SEVERITY {Warning} [get_drc_checks UCIO-1]
