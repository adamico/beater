def tick args
  if args.state.tick_count == 0
    stat = $gtk.stat_file("pacman.gmm")
    puts "stat: #{stat}"
    $gtk.exit
  end
end
