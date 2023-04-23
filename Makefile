all: shards prebuild build-static strip

shards:
	shards install --production
shards-devel:
	shards install
prebuild:
	mkdir -p bin
build: prebuild
	crystal build --release --no-debug -s -p -t src/moosefs_exporter.cr -o bin/moosefs_exporter
build-static:
	crystal build --release --static --no-debug -s -p -t src/moosefs_exporter.cr -o bin/moosefs_exporter
strip:
	strip bin/moosefs_exporter
run:
	crystal run src/moosefs_exporter.cr
test: shards-devel
	./bin/ameba
