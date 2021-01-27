CC=clang
CFLAGS=-Wall -O2 -g

FRAMEWORKS=-framework Foundation -framework IOKit

TARGETS=sensors

all: ${TARGETS}

sensors: sensors.o
	${CC} -o $@ $< ${FRAMEWORKS} ${LIBS}

clean:
	rm -rf ${TARGETS} *.o
