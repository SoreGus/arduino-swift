.PHONY: verify compile upload monitor clean

verify:
	./run.sh verify

compile:
	./run.sh compile

upload:
	./run.sh upload

monitor:
	./run.sh monitor

clean:
	./run.sh clean