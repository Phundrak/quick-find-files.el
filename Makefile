EMACS ?= emacs
EASK ?= eask

.PHONY: clean package install compile test checkdoc lint

ci: clean package install compile checkdoc lint

package:
	@echo "Packaging..."
	$(EASK) package

install:
	@echo "Installing..."
	$(EASK) install

compile:
	@echo "Compiling..."
	$(EASK) compile

test:
	@echo "Testing..."
	$(EASK) install-deps --dev
	$(EASK) test ert ./test/*.el

checkdoc:
	@echo "Checking documentation..."
	$(EASK) lint checkdoc --strict

lint:
	@echo "Linting..."
	$(EASK) lint package

clean:
	$(EASK) clean all
