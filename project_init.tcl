# utility function
proc get_repo_dir {} {
    set projdir [get_property DIRECTORY [current_project]]
    set projdirlist [ file split $projdir ]
    set basedirlist [ lreplace $projdirlist end end ]
    return [ file join {*}$basedirlist ]
}

# source utilities
source [file join [get_repo_dir] "submodules" "verilog-library-barawn" "tclbits" "utility.tcl"]
# source repo control
source [file join [get_repo_dir] "submodules" "verilog-library-barawn" "tclbits" "repo_files.tcl"]

# Make sure the project behavior stays the same.
set f [open [ file join [get_repo_dir] "barawn_repository" ] ]
set repo [read $f]
add_ip_repository $repo

# Add pre-synthesis script if needed
set_pre_synthesis_tcl "pre_synthesis.tcl"

# And check if everything's loaded.
check_all
