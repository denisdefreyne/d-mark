.PHONY: all
all: target/d-mark target/d-mark_0.1-1.deb

.PHONY: clean
clean:
	@echo "=== Cleaning $@..."
	rm -rf target
	@echo

target/d-mark:
	@echo "=== Building $@..."
	mkdir -p target
	crystal build --release -o $@ src/d-mark/cli.cr
	@echo

target/d-mark_0.1-1: target/d-mark
	@echo "=== Building $@..."
	rm -rf $@
	cp -r deb_template $@
	mkdir -p $@/usr/local/bin
	cp $< $@/usr/local/bin/d-mark
	@echo

target/d-mark_0.1-1.deb: target/d-mark_0.1-1
	@echo "=== Building $@..."
	dpkg-deb --build target/d-mark_0.1-1
	@echo
