PREFIX = /usr
CC ?= gcc
AR ?= ar

FP_TYPE ?= float
CONFIG  ?= Debug

LRHSMM_SERIALIZATION = true

OUT_DIR = ./build
OBJS = $(OUT_DIR)/common.o \
  $(OUT_DIR)/math-funcs.o \
	$(OUT_DIR)/mempool.o \
	$(OUT_DIR)/model.o \
  $(OUT_DIR)/data.o \
	$(OUT_DIR)/generate.o \
	$(OUT_DIR)/inference.o \
  $(OUT_DIR)/estimate.o
ifeq ($(LRHSMM_SERIALIZATION), true)
  OBJS += $(OUT_DIR)/cmp.o $(OUT_DIR)/serial.o
endif

ARFLAGS = -rv
CFLAGS_COMMON = -DFP_TYPE=$(FP_TYPE) -std=c99 -Wall -fPIC
ifeq ($(CXX), emcc)
  CFLAGS_DBG = $(CFLAGS_COMMON) -O1 -g -D_DEBUG
  CFLAGS_REL = $(CFLAGS_COMMON) -O3
else
  CFLAGS_DBG = $(CFLAGS_COMMON) -Og -g -D_DEBUG
  CFLAGS_REL = $(CFLAGS_COMMON) -Ofast
endif
ifeq ($(CONFIG), Debug)
  CFLAGS = $(CFLAGS_DBG)
else
  CFLAGS = $(CFLAGS_REL)
endif

default: $(OUT_DIR)/liblrhsmm.a

test: test-mempool test-random-model test-state-jumps 
.PRECIOUS: $(OUT_DIR)/test-mempool \
	$(OUT_DIR)/test-random-model \
	$(OUT_DIR)/test-state-jumps \
	$(OUT_DIR)/test-mempool.js \
	$(OUT_DIR)/test-random-model.js \
	$(OUT_DIR)/test-state-jumps.js

ifeq ($(CXX), emcc)
test-%: $(OUT_DIR)/test-%.js
	node $(OUT_DIR)/test-$*.js
else
test-%: $(OUT_DIR)/test-%
	$(OUT_DIR)/test-$*
endif

$(OUT_DIR)/liblrhsmm.a: $(OBJS)
	$(AR) $(ARFLAGS) $(OUT_DIR)/liblrhsmm.a $(OBJS)
	@echo Done.

$(OUT_DIR)/test-%: test/test-%.c test/test-common.h $(OUT_DIR)/liblrhsmm.a
	$(CC) test/test-$*.c $(OUT_DIR)/liblrhsmm.a $(CFLAGS) -Wno-unused-function \
	  -lm -o $(OUT_DIR)/test-$*

$(OUT_DIR)/test-%.js: test/test-%.c test/test-common.h $(OUT_DIR)/liblrhsmm.a
	$(CC) test/test-$*.c $(OUT_DIR)/liblrhsmm.a $(CFLAGS) -Wno-unused-function \
	  -lm -o $(OUT_DIR)/test-$*.js -s TOTAL_MEMORY=512MB

$(OUT_DIR)/common.o: common.c common.h
$(OUT_DIR)/mempool.o: mempool.c mempool.h
$(OUT_DIR)/model.o: model.c model.h math-funcs.h common.h
$(OUT_DIR)/math-funcs.o: math-funcs.c math-funcs.h
$(OUT_DIR)/data.o: data.c data.h common.h
$(OUT_DIR)/generate.o: generate.c generate.h math-funcs.h common.h
$(OUT_DIR)/inference.o: inference.c inference.h inference-helper.h inference-forward.h \
  inference-forward-geometric.h model.h data.h mempool.h math-funcs.h common.h
$(OUT_DIR)/estimate.o: estimate.c estimate.h inference-helper.h model.h data.h common.h
$(OUT_DIR)/serial.o: serial.c serial.h data.h model.h common.h
$(OUT_DIR)/cmp.o:
	mkdir -p build
	$(CC) $(CFLAGS) -o $(OUT_DIR)/cmp.o -c external/cmp/cmp.c

$(OUT_DIR)/%.o : %.c
	mkdir -p build
	$(CC) $(CFLAGS) -o $(OUT_DIR)/$*.o -c $*.c

install: $(OUT_DIR)/liblrhsmm.a 
	mkdir -p $(PREFIX)/lib $(PREFIX)/include/liblrhsmm
	cp $(OUT_DIR)/liblrhsmm.a $(PREFIX)/lib
	cp model.h mempool.h inference.h estimate.h data.h generate.h common.h \
	  $(PREFIX)/include/liblrhsmm

clean:
	@echo 'Removing all temporary binaries...'
	@rm -f $(OUT_DIR)/*.a $(OUT_DIR)/*.o
	@echo Done.

