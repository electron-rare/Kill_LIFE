install:
	@pip install bandit pip-audit semgrep coverage Wokwi KiBot kicad-cli k6 locust

bandit:
	bandit -r .

pip-audit:
	pip-audit

semgrep:
	semgrep --config .semgrep.yml .

coverage:
	coverage run -m pytest
	coverage report
	coverage html

wokwi:
	wokwi-cli

kibot:
	kibot --config hardware/esp32_minimal/.kibot.yaml

k6:
	k6 run performance/k6/smoke.js

locust:
	locust -f performance/locustfile.py

.PHONY: install bandit pip-audit semgrep coverage wokwi kibot k6 locust