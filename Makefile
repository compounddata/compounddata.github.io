#!/usr/bin/env make

.PHONY: build
build:
	hugo --cleanDestinationDir

.PHONY: serve
serve: build
	hugo serve --bind 127.0.0.1 --baseUrl http://127.0.0.1 --buildDrafts --watch --liveReloadPort 1313 --disableLiveReload=false
