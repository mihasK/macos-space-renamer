.PHONY: app-start app-stop app-restart app-status login-install login-uninstall login-status package run rerun stop status

app-start run:
	./scripts/app.sh start

app-stop stop:
	./scripts/app.sh stop

app-restart rerun:
	./scripts/app.sh restart

app-status status:
	./scripts/app.sh status

login-install:
	./scripts/login-item.sh install

login-uninstall:
	./scripts/login-item.sh uninstall

login-status:
	./scripts/login-item.sh status

package:
	./scripts/package-app.sh
