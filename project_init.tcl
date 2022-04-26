set f [open "barawn_repository"]
set repo [read $f]
puts "Updating IP repo with ${repo}"
set_property ip_repo_paths $repo [current_project]
 
