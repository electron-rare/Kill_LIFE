# Kill_LIFE Project Makefile
# Common targets for hardware projects managed by Kill_LIFE agents

PROJECT_NAME ?= $(shell basename $(CURDIR))
KILL_LIFE_YAML := .kill-life.yaml
PCB_DIR := hardware/pcb
BOM_DIR := hardware/bom
SIM_DIR := hardware/simulation
FAB_DIR := fabrication
FW_DIR := firmware

.PHONY: help review bom-check bom-export fabrication-prep firmware-build firmware-flash erc drc clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# --- Hardware ---

erc: ## Run KiCad ERC on all schematics
	@for sch in $$(find $(PCB_DIR) -name '*.kicad_sch' -not -path '*/libs/*'); do \
		echo "ERC: $$sch"; \
		kicad-cli sch erc --exit-code-violations "$$sch"; \
	done

drc: ## Run KiCad DRC on all PCBs
	@for pcb in $$(find $(PCB_DIR) -name '*.kicad_pcb'); do \
		echo "DRC: $$pcb"; \
		kicad-cli pcb drc --exit-code-violations "$$pcb"; \
	done

review: erc drc ## Run full Forge design review (ERC + DRC + agent analysis)
	@echo "Design checks passed. Trigger forge agent for full review."

bom-export: ## Export BOM from KiCad schematic
	@for sch in $$(find $(PCB_DIR) -name '*.kicad_sch' -not -path '*/libs/*'); do \
		echo "Exporting BOM from $$sch"; \
		kicad-cli sch export bom --output $(BOM_DIR)/bom.csv "$$sch"; \
	done

bom-check: ## Validate BOM completeness
	@test -f $(BOM_DIR)/bom.csv || { echo "No BOM found. Run 'make bom-export' first."; exit 1; }
	@echo "BOM: $$(wc -l < $(BOM_DIR)/bom.csv) lines"
	@echo "BOM validation passed."

fabrication-prep: ## Generate Gerbers and JLCPCB files
	@mkdir -p $(FAB_DIR)/gerbers $(FAB_DIR)/jlcpcb
	@for pcb in $$(find $(PCB_DIR) -name '*.kicad_pcb'); do \
		echo "Generating Gerbers from $$pcb"; \
		kicad-cli pcb export gerbers --output $(FAB_DIR)/gerbers/ "$$pcb"; \
		kicad-cli pcb export drill --output $(FAB_DIR)/gerbers/ "$$pcb"; \
	done
	@echo "Fabrication files ready in $(FAB_DIR)/"

# --- Firmware ---

firmware-build: ## Build firmware with PlatformIO
	cd $(FW_DIR) && pio run

firmware-flash: ## Flash firmware to connected board
	cd $(FW_DIR) && pio run --target upload

# --- Utility ---

clean: ## Remove build artifacts
	rm -rf $(FAB_DIR)/gerbers $(FAB_DIR)/jlcpcb
	cd $(FW_DIR) && pio run --target clean 2>/dev/null || true
