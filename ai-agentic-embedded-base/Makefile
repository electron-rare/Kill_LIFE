.PHONY: fw hw s0 docs

s0:
	python tools/cockpit/cockpit.py gate_s0

fw:
	python tools/cockpit/cockpit.py fw

hw:
	@echo "usage: make hw SCHEM=hardware/kicad/<p>/<p>.kicad_sch"
	bash tools/hw/hw_check.sh $(SCHEM)

docs:
	python -m pip install -U mkdocs
	mkdocs build --strict

compliance:
	python tools/compliance/validate.py --strict
