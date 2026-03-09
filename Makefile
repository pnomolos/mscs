UNAME_S := $(shell uname -s)
MSCS_USER := minecraft

ifeq ($(UNAME_S),Darwin)
  HOMEBREW_PREFIX := $(shell [ -d /opt/homebrew ] && echo /opt/homebrew || echo /usr/local)
  MSCTL := $(HOMEBREW_PREFIX)/bin/msctl
  MSCS := $(HOMEBREW_PREFIX)/bin/mscs
  MSCS_HOME := $(HOMEBREW_PREFIX)/var/mscs
  MSCS_CONF_DIR := $(HOMEBREW_PREFIX)/etc/mscs
  MSCS_COMPLETION := $(HOMEBREW_PREFIX)/share/bash-completion/completions/mscs
  LAUNCHD_PLIST := /Library/LaunchDaemons/com.mscs.all.plist
  LAUNCHD_WRAPPER := $(HOMEBREW_PREFIX)/bin/mscs-launchd-wrapper.sh
  MSCS_LOG_DIR := /var/log/mscs
else
  MSCTL := /usr/local/bin/msctl
  MSCS := /usr/local/bin/mscs
  MSCS_HOME := /opt/mscs
  MSCS_INIT_D := /etc/init.d/mscs
  MSCS_SERVICE := /etc/systemd/system/mscs.service
  MSCS_SERVICE_TEMPLATE := /etc/systemd/system/mscs@.service
  # Bash completion: detect proper location
  BASH_COMPLETION_DIR := $(shell \
  	if [ -d /usr/share/bash-completion/completions ]; then \
  		echo /usr/share/bash-completion/completions; \
  	else \
  		echo /etc/bash_completion.d; \
  	fi)
  MSCS_COMPLETION := $(BASH_COMPLETION_DIR)/mscs
endif

UPDATE_D := $(wildcard update.d/*)

.PHONY: install adduser update clean

ifeq ($(UNAME_S),Darwin)

install: adduser update
	mkdir -p $(MSCS_LOG_DIR)
	chown $(MSCS_USER) $(MSCS_LOG_DIR)
	launchctl bootstrap system $(LAUNCHD_PLIST) 2>/dev/null || \
		launchctl load -w $(LAUNCHD_PLIST)

adduser:
	@if id $(MSCS_USER) >/dev/null 2>&1; then \
		echo "Minecraft user $(MSCS_USER) exists so not creating it"; \
	else \
		NEXT_UID=$$(dscl . -list /Users UniqueID | awk '$$2 > max { max = $$2 } END { uid = (max < 400 ? 401 : max + 1); print uid }'); \
		echo "Creating user $(MSCS_USER) with UID $$NEXT_UID"; \
		dscl . -create /Users/$(MSCS_USER); \
		dscl . -create /Users/$(MSCS_USER) UniqueID $$NEXT_UID; \
		dscl . -create /Users/$(MSCS_USER) PrimaryGroupID $$NEXT_UID; \
		dscl . -create /Users/$(MSCS_USER) UserShell /usr/bin/false; \
		dscl . -create /Users/$(MSCS_USER) NFSHomeDirectory $(MSCS_HOME); \
		dscl . -create /Groups/$(MSCS_USER); \
		dscl . -create /Groups/$(MSCS_USER) PrimaryGroupID $$NEXT_UID; \
		dscl . -create /Groups/$(MSCS_USER) RealName "Minecraft Server"; \
		mkdir -p $(MSCS_HOME); \
		chown $(MSCS_USER):$(MSCS_USER) $(MSCS_HOME); \
	fi

update:
	install -m 0755 msctl $(MSCTL)
	install -m 0755 mscs $(MSCS)
	install -m 0755 mscs-launchd-wrapper.sh $(LAUNCHD_WRAPPER)
	install -m 0644 com.mscs.all.plist $(LAUNCHD_PLIST)
	mkdir -p $(MSCS_CONF_DIR)
	mkdir -p $(dir $(MSCS_COMPLETION))
	install -m 0644 mscs.completion $(MSCS_COMPLETION)
	@for script in $(UPDATE_D); do \
		sh $$script; \
	done; true;

clean:
	-launchctl bootout system/com.mscs.all 2>/dev/null || \
		launchctl unload $(LAUNCHD_PLIST) 2>/dev/null; true
	rm -f $(LAUNCHD_PLIST) $(LAUNCHD_WRAPPER)
	rm -f $(MSCTL) $(MSCS) $(MSCS_COMPLETION)
	-rmdir $(MSCS_CONF_DIR) 2>/dev/null; true

else

install: adduser update
	if which systemctl; then \
		systemctl -f enable mscs.service; \
	else \
		ln -s $(MSCS) $(MSCS_INIT_D); \
		update-rc.d mscs defaults; \
	fi

adduser:
	# safety check to see if user exists before trying to create it
	if id $(MSCS_USER); then \
		echo "Minecraft user $(MSCS_USER) exists so not creating it"; \
	else \
		useradd --system --user-group --create-home -K UMASK=0022 --home $(MSCS_HOME) $(MSCS_USER); \
	fi

update:
	install -m 0755 msctl $(MSCTL)
	install -m 0755 mscs $(MSCS)
	install -m 0644 mscs.completion $(MSCS_COMPLETION)
	if which systemctl; then \
		install -m 0644 mscs.service $(MSCS_SERVICE); \
		install -m 0644 mscs@.service $(MSCS_SERVICE_TEMPLATE); \
	fi
	@for script in $(UPDATE_D); do \
		sh $$script; \
	done; true;

clean:
	if which systemctl; then \
		systemctl -f disable mscs.service; \
		rm -f $(MSCS_SERVICE) $(MSCS_SERVICE_TEMPLATE); \
	else \
		update-rc.d mscs remove; \
		rm -f $(MSCS_INIT_D); \
	fi
	rm -f $(MSCTL) $(MSCS) $(MSCS_COMPLETION)

endif
