test:
	bash tests/test.sh

sample:
	mkdir -p docs site
	bin/shell-risk examples > docs/sample-output.txt; true
	bin/shell-risk examples --tsv > docs/sample-output.tsv; true
	python3 scripts/site.py docs/sample-output.tsv site/index.html "shell-risk" "Security linter for shell scripts: curl|sh, eval on input, rm -rf with unguarded variables, chmod 777, setuid, hardcoded secrets and TLS checks switched off. Pure Bash." "Synthetic scripts."
