.PHONY: all
all: target/d-mark

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
