.PHONY: all
all: target/d-mark target/d-mark_0.1-1.deb

target/d-mark:
	mkdir -p target
	crystal build --release -o $@ src/d-mark/cli.cr

target/d-mark_0.1-1: target/d-mark
	rm -rf $@
	cp -r deb_template $@
	mkdir -p $@/usr/local/bin
	cp $< $@/usr/local/bin/d-mark

target/d-mark_0.1-1.deb: target/d-mark_0.1-1
	dpkg-deb --build target/d-mark_0.1-1
