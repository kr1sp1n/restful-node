SHELL := /bin/bash
NODE_PATH = $(shell ./scripts/find-node-or-install)
PATH := $(NODE_PATH):$(shell echo $$PATH)

MOCHA_BIN = node_modules/.bin/mocha

REPORTER = spec 

all: build

build:

install: modules

modules:
	npm install .

test: $(MOCHA_BIN) test-unit

test-unit: $(MOCHA_BIN) 
	$(MOCHA_BIN) --reporter $(REPORTER)

# for jenkins
test-report: $(MOCHA_BIN)
	$(MOCHA_BIN) --reporter xunit > xunit.xml


$(MOCHA_BIN): build
	
.PHONY: all
