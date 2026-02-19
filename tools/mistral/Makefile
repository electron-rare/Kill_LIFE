# Mistral pack helper
venv:
	python -m venv .venv && . .venv/bin/activate && pip install -r requirements-mistral.txt

patch-spec:
	python tools/mistral/mistral_generate_patch.py --model codestral-latest --scope ai:spec --request "$(REQ)" --out /tmp/patch.json

apply-spec:
	python tools/mistral/apply_safe_patch.py --scope ai:spec --patch /tmp/patch.json

index:
	python tools/mistral/index_repo.py

search:
	python tools/mistral/search_index.py --query "$(Q)" --topk 5
