default:
	@dub run

fast:
	@dub run --build=release

debug:
	DFLAGS="-g -gc -d-debug" dub build  && gdb -q -ex run ./the_mill

install:
	dub upgrade
	dub run raylib-d:install

clean:
	dub clean