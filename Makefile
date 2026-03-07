# Rapport de couverture des tests Python
coverage:
	python3 -m coverage run -m pytest
	python3 -m coverage html -d docs/coverage_report

CAD_STACK ?= ./tools/hw/cad_stack.sh
CAD_ARGS ?=

.PHONY: coverage fw hw s0 docs compliance cad-up cad-down cad-ps cad-build cad-doctor cad-mcp cad-kicad cad-freecad cad-pio

s0:
	python3 tools/cockpit/cockpit.py gate_s0

fw:
	python3 tools/cockpit/cockpit.py fw

hw:
	@echo "usage: make hw SCHEM=hardware/kicad/<p>/<p>.kicad_sch"
	bash tools/hw/hw_check.sh $(SCHEM)

docs:
	python3 -m pip install -U mkdocs
	mkdocs build --strict

compliance:
	python3 tools/compliance/validate.py --strict

cad-up:
	$(CAD_STACK) up $(CAD_ARGS)

cad-down:
	$(CAD_STACK) down

cad-ps:
	$(CAD_STACK) ps

cad-build:
	$(CAD_STACK) build $(CAD_ARGS)

cad-doctor:
	$(CAD_STACK) doctor

cad-mcp:
	$(CAD_STACK) mcp $(CAD_ARGS)

cad-kicad:
	@if [ -z "$(CAD_ARGS)" ]; then echo "usage: make cad-kicad CAD_ARGS='version'"; exit 1; fi
	$(CAD_STACK) kicad-cli $(CAD_ARGS)

cad-freecad:
	@if [ -z "$(CAD_ARGS)" ]; then echo "usage: make cad-freecad CAD_ARGS='-c \"import FreeCAD; print(FreeCAD.Version())\"'"; exit 1; fi
	$(CAD_STACK) freecad-cmd $(CAD_ARGS)

cad-pio:
	@if [ -z "$(CAD_ARGS)" ]; then echo "usage: make cad-pio CAD_ARGS='system info'"; exit 1; fi
	$(CAD_STACK) pio $(CAD_ARGS)
