all: askpass daemon function

clean:
	rm -fr *.exe *.dll

install: all
	cp -f askpass daemon function.dll ../../bin/

askpass: askpass.cpp
	g++ askpass.cpp -o askpass
	strip askpass.exe

daemon: daemon.cpp
	g++ daemon.cpp -o daemon
	strip daemon.exe

function: function.cpp
	g++ -shared function.cpp -l Userenv -l Wtsapi32 -o function.dll
	strip function.dll
