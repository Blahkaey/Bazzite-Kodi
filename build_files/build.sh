#!/bin/bash
set -euo pipefail

source "/ctx/utility.sh"

install_kodi_dependencies() {
    log_subsection "Installing Kodi runtime dependencies"

    if [[ ! -f "/var/tmp/runtime-deps.txt" ]]; then
        log_error "Runtime dependencies file not found!"
        exit 1
    fi

    log_info "Checking which dependencies are already installed..."
    missing_deps=""

    while IFS= read -r pkg; do
        if [[ -n "$pkg" ]]; then
            if ! rpm -q "$pkg" &>/dev/null; then
                missing_deps="$missing_deps $pkg"
            else
                log_success "$pkg already installed"
            fi
        fi
    done < /var/tmp/runtime-deps.txt

    if [[ -n "$missing_deps" ]]; then
        log_info "Installing missing dependencies:$missing_deps"
        if ! dnf -y --nogpgcheck --setopt=strict=0 install $missing_deps >/dev/null 2>&1; then
            log_warning "Failed to install some dependencies, attempting individually..."
            for pkg in $missing_deps; do
                dnf -y --nogpgcheck install "$pkg" || log_warning "Could not install $pkg"
            done
        fi
    else
        log_success "All dependencies already installed!"
    fi

    # Clean up
    rm -f /var/tmp/runtime-deps.txt
    ldconfig
    dnf clean all
}

main() {
    log_section "Bazzite-Kodi Build Process"

    install_kodi_dependencies

    dnf5 -y install inotify-tools drm-utils drm_info edid-decode java-21-openjdk
    dnf5 -y --enablerepo=updates-testing install qbittorrent-nox-5.1.2-1.fc42

    run_stage "Installing polkit rules" "/bin/bash /ctx/components/install-polkit.sh"
    run_stage "Installing session switching system" "/bin/bash /ctx/components/install-session-switching.sh"
    run_stage "Setting up Kodi service" "/bin/bash /ctx/components/install-kodi-service.sh"
    run_stage "Pre-staging DeckyLoader components" "/bin/bash /ctx/components/install-deckyloader-prep.sh"
    run_stage "Installing first boot setup" "/bin/bash /ctx/components/install-firstboot.sh"

    log_success "Bazzite-Kodi build completed successfully!"
}

run_stage() {
    local stage_name="$1"
    local script_command="$2"

    log_subsection "$stage_name"

    if ! eval "$script_command"; then
        log_error "Stage failed: $stage_name"
        exit 1
    fi

    log_success "$stage_name completed"
}

main "$@"
