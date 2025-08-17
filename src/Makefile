CC ?= gcc
CFLAGS ?= -Wall -Wextra -O2
LDFLAGS ?= -lnetfilter_log -lnetfilter_queue -ljson-c -lsqlite3

TARGET = netmon
SOURCES = netmon.c network_utils.c db_manager.c

all: $(TARGET)

$(TARGET): $(SOURCES)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

clean:
	rm -f $(TARGET)

.PHONY: all clean
