SRCDIR = src
OBJDIR = obj
BINDIR = bin
TARGET = sprite.nes

SOURCES := $(wildcard $(SRCDIR)/*.asm)
OBJECTS := $(SOURCES:$(SRCDIR)/%.asm=$(OBJDIR)/%.o)
rm      = rm -f

.PHONY: all
all: directories $(BINDIR)/$(TARGET)

.PHONY: directories
directories:
	@mkdir -p $(OBJDIR)
	@mkdir -p $(BINDIR)

$(BINDIR)/$(TARGET): $(OBJECTS)
	cl65 -t nes -o $@ $(OBJECTS)

$(OBJECTS): $(OBJDIR)/%.o : $(SRCDIR)/%.asm
	ca65 -o $@ $<

.PHONY: clean
clean:
	@$(rm) $(BINDIR)/*
	@$(rm) $(OBJECTS)
