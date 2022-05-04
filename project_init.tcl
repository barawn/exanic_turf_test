proc get_repo_dir {} {
    set projdir [get_property DIRECTORY [current_project]]
    set projdirlist [ file split $projdir ]
    set basedirlist [ lreplace $projdirlist end end ]
    return [ file join {*}$basedirlist ]
}
		  
set f [open [ file join [get_repo_dir] "barawn_repository" ] ]
set repo [read $f]
puts "Updating IP repo with ${repo}"
set_property ip_repo_paths $repo [current_project]
puts "Updating pre init script"
set pre [ file join [get_repo_dir] "pre_synthesis.tcl"]
set_property STEPS.SYNTH_DESIGN.TCL.PRE [ get_files $pre -of [get_fileset utils_1] ] [get_runs synth_1]

