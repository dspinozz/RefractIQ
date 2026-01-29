CC = gcc
CFLAGS = -Wall -Wextra -std=c11 -O2
LDFLAGS = -lcurl

TARGET = refract_client
SRCDIR = src
SOURCES = $(SRCDIR)/main.c $(SRCDIR)/http_client.c $(SRCDIR)/queue.c
OBJECTS = $(SOURCES:.c=.o)

.PHONY: all clean install

all: $(TARGET)

$(TARGET): $(OBJECTS)
	$(CC) $(OBJECTS) -o $(TARGET) $(LDFLAGS)

$(SRCDIR)/%.o: $(SRCDIR)/%.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJECTS) $(TARGET) queue.log

install: $(TARGET)
	cp $(TARGET) /usr/local/bin/

# Development target: run with example values
test: $(TARGET)
	./$(TARGET) -d TEST001 -v 1.3330 -u RI -t 25.0
