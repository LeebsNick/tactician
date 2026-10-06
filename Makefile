.PHONY: lint test check mutate dist stage

lint:
	luacheck .

test:
	luajit tests/run.lua tactician

check: lint test

# Manual mutation pass; see tools/mutants.txt. MODULE=tactician/lib/<file>.lua to limit it.
mutate:
	luajit tools/mutate.lua $(MODULE)

# Release zip under dist/: make dist VER=1.0.0
dist:
	sh tools/dist.sh $(VER) tactician

# Unzipped tree under dist/stage/ashita/tactician/ to symlink into Ashita/addons/.
stage:
	sh tools/dist.sh dev tactician
