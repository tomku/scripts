# Scripts

This repository contains various short scripts that I've found it useful to
write.

## tartime.rb

`tartime.rb` creates timestamped, compressed snapshot tarballs of a folder.
It's intended to be used for small, non-code folders as it doesn't
deduplicate or back up incrementally.

## repo_man.rb

`repo_man.rb` keeps a folder full of cloned git/hg/fossil repositories up to
date. I use it for code that I reference or read, so it doesn't have to deal
with merge conflicts or unclean working directories.
