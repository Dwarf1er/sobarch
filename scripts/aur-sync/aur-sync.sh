#!/usr/bin/env bash
# Builds and installs packages vendored in packages/aur/ and
# packages/custom/. Never builds anything not vendored there.
#
#   aur-sync.sh [--local DIR] [--cache DIR] PKG...      install the named packages
#   aur-sync.sh [--local DIR] [--cache DIR] [--notify]  update installed ones only
#
# --local DIR   use an existing checkout instead of fetching the repo
# --cache DIR   install prebuilt *.pkg.tar.* files when they satisfy the pin
# --notify      send a desktop notification on failure

set -euo pipefail
shopt -s inherit_errexit

REPO="Dwarf1er/sobarch"
BRANCH="master"
ARCHIVE_URL="https://github.com/${REPO}/archive/refs/heads/${BRANCH}.tar.gz"

BUILD_USER="sobarch-build"
LOG_FILE="/var/log/sobarch/aur-sync.log"

mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

# Our own pacman calls re-fire the pacman hook; the inherited marker makes
# that nested run exit immediately.
if [[ -n "${SOBARCH_AUR_SYNC_RUNNING:-}" ]]; then
    echo "aur-sync: nested run (own pacman transaction retriggered the hook), skipping"
    exit 0
fi
export SOBARCH_AUR_SYNC_RUNNING=1

# One sync at a time; waiters find nothing left to do.
mkdir -p /run/lock
exec 9>/run/lock/sobarch-aur-sync.lock
flock 9

echo "aur-sync: run started $(date -Iseconds)"

repo_dir=""
cache_dir=""
notify_on_failure=false
while [[ "${1:-}" == "--local" || "${1:-}" == "--cache" || "${1:-}" == "--notify" ]]; do
    case "$1" in
        --local) repo_dir="$2"; shift 2 ;;
        --cache) cache_dir="$2"; shift 2 ;;
        --notify) notify_on_failure=true; shift ;;
    esac
done
explicit_packages=("$@")

cleanup_paths=()
# makepkg refuses to run as root, so builds run as a dedicated system user.
ensure_build_user() {
    id -u "$BUILD_USER" >/dev/null 2>&1 && return 0
    echo "aur-sync: creating build user $BUILD_USER..."
    useradd --system --create-home --home-dir "/var/lib/$BUILD_USER" \
        --shell /usr/bin/nologin "$BUILD_USER"
}

# Runs a command and logs its duration to stderr. Returns its exit status.
timed() {
    local label="$1" start=$SECONDS rc=0
    shift
    "$@" || rc=$?
    echo "[timing] aur-sync $label: $((SECONDS - start))s" >&2
    return "$rc"
}

fetch_repo() {
    local dir start=$SECONDS
    dir="$(mktemp -d /var/tmp/sobarch-aur-sync-repo.XXXXXX)"
    # stderr: stdout is the function's return value.
    echo "aur-sync: fetching current repo state from ${REPO}@${BRANCH}..." >&2
    curl -fsSL --connect-timeout 20 --max-time 600 "$ARCHIVE_URL" | tar -xz -C "$dir" --strip-components=1
    echo "[timing] aur-sync fetch repo: $((SECONDS - start))s" >&2
    echo "$dir"
}

trap 'rm -rf "${cleanup_paths[@]}"' EXIT

if [[ -z "$repo_dir" ]]; then
    # fetch_repo runs in a subshell, so register the cleanup here.
    repo_dir="$(fetch_repo)"
    cleanup_paths+=("$repo_dir")
elif [[ ! -d "$repo_dir" ]]; then
    echo "aur-sync: --local $repo_dir does not exist" >&2
    exit 1
fi

if [[ -n "$cache_dir" && ! -d "$cache_dir" ]]; then
    echo "aur-sync: --cache $cache_dir does not exist" >&2
    exit 1
fi

# Every package this script is allowed to touch: name -> source dir.
declare -A pkg_dir
for group in aur custom; do
    [[ -d "$repo_dir/packages/$group" ]] || continue
    for dir in "$repo_dir/packages/$group"/*/; do
        [[ -d "$dir" ]] || continue
        pkg_dir["$(basename "$dir")"]="${dir%/}"
    done
done

targets=()
scope_failures=()
if ((${#explicit_packages[@]})); then
    for name in "${explicit_packages[@]}"; do
        if [[ -n "${pkg_dir[$name]:-}" ]]; then
            targets+=("$name")
        else
            scope_failures+=("$name")
        fi
    done
    if ((${#scope_failures[@]})); then
        echo "aur-sync: refusing to build unvendored package(s): ${scope_failures[*]}" >&2
    fi

    # Companions ride along with another package and appear in no profile.
    # Once installed, sync mode keeps them current.
    declare -A companion_of=(
        [vesktop-bin]=vesktop-integrity-launch
    )
    for name in "${explicit_packages[@]}"; do
        companion="${companion_of[$name]:-}"
        [[ -n "$companion" && -n "${pkg_dir[$companion]:-}" ]] || continue
        [[ " ${targets[*]} " == *" $companion "* ]] || targets+=("$companion")
    done
else
    for name in "${!pkg_dir[@]}"; do
        pacman -Q "$name" >/dev/null 2>&1 && targets+=("$name")
    done
fi

# Pinned version from .SRCINFO in vercmp's epoch:pkgver-pkgrel form.
# -git packages recompute pkgver() at build time, so for them this
# comparison won't notice upstream changes once installed.
pinned_version() {
    local srcinfo="$1/.SRCINFO" epoch pkgver pkgrel
    if [[ ! -f "$srcinfo" ]]; then
        echo "aur-sync: $srcinfo does not exist" >&2
        return 1
    fi
    epoch="$(awk -F' = ' '/^[[:space:]]*epoch = /{print $2; exit}' "$srcinfo")"
    pkgver="$(awk -F' = ' '/^[[:space:]]*pkgver = /{print $2; exit}' "$srcinfo")"
    pkgrel="$(awk -F' = ' '/^[[:space:]]*pkgrel = /{print $2; exit}' "$srcinfo")"
    if [[ -z "$pkgver" || -z "$pkgrel" ]]; then
        echo "aur-sync: $srcinfo has no pkgver/pkgrel" >&2
        return 1
    fi
    if [[ -n "$epoch" ]]; then
        echo "${epoch}:${pkgver}-${pkgrel}"
    else
        echo "${pkgver}-${pkgrel}"
    fi
}

installed_version() {
    pacman -Q "$1" 2>/dev/null | awk '{print $2}' || true
}

# Prints a cached package file for $1 whose version is at least $2.
cached_pkgfile() {
    local name="$1" pinned="$2" f qname qver
    [[ -n "$cache_dir" ]] || return 1
    for f in "$cache_dir/$name"-*.pkg.tar.*; do
        [[ -f "$f" ]] || continue
        read -r qname qver < <(pacman -Qp "$f" 2>/dev/null)
        [[ "$qname" == "$name" ]] || continue
        (( $(vercmp "$qver" "$pinned") >= 0 )) || continue
        printf '%s' "$f"
        return 0
    done
    return 1
}

# depends/makedepends from .SRCINFO without version constraints. Names
# provided by the same pkgbase's split packages are dropped, since they
# are installed together by one pacman -U.
build_deps() {
    awk -F' = ' '
        /^[[:space:]]*pkgname = / { own[$2] = 1 }
        /^[[:space:]]*(depends|makedepends) = / { dep = $2; sub(/[<>=].*/, "", dep); deps[++n] = dep }
        END { for (i = 1; i <= n; i++) if (!(deps[i] in own)) print deps[i] }
    ' "$1/.SRCINFO"
}

# makepkg never fetches missing PGP keys and the build user's keyring
# starts empty.
import_pgp_keys() {
    local src="$1" key
    while IFS= read -r key; do
        [[ -n "$key" ]] || continue
        runuser -u "$BUILD_USER" -- gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys "$key" || return 1
    done < <(awk -F' = ' '/^[[:space:]]*validpgpkeys = /{print $2}' "$src/.SRCINFO")
}

# Retries while db.lck exists, since pacman fails immediately on a held lock.
pacman_locked() {
    local attempt
    for attempt in {1..10}; do
        pacman "$@" && return 0
        [[ -f /var/lib/pacman/db.lck ]] || return 1
        echo "aur-sync: pacman database locked, retrying ($attempt/10)..." >&2
        sleep 3
    done
    return 1
}

# PKGBUILDs may assume base-devel without declaring it.
ensure_makepkg_prereqs() {
    pacman_locked -S --needed --noconfirm base-devel
}

failures=()
first_install=true

# Created on the first real build only, so all-cached runs skip the
# build user, base-devel and repo copy. The whole repo is copied because
# sobarch-skel reaches skel/ through a relative path, and it's per-run so
# concurrent runs never share a build tree.
build_root_repo=""

for name in $(printf '%s\n' "${targets[@]}" | sort); do
    src="${pkg_dir[$name]}"
    if ! pinned="$(pinned_version "$src")"; then
        failures+=("$name (unreadable .SRCINFO)")
        continue
    fi
    installed="$(installed_version "$name")"

    if [[ -n "$installed" ]] && (( $(vercmp "$pinned" "$installed") <= 0 )); then
        echo "aur-sync: $name is up to date ($installed)."
        continue
    fi

    build_dir=""
    if cached="$(cached_pkgfile "$name" "$pinned")"; then
        # A cache hit needs no build deps or PGP keys; pacman -U resolves
        # runtime deps itself.
        echo "aur-sync: $name found in cache, skipping build (${installed:-not installed} -> $pinned)..."
        pkgfiles=("$cached")
    else
        echo "aur-sync: building $name (${installed:-not installed} -> $pinned)..."

        # Deps are installed as root rather than via `makepkg --syncdeps`,
        # which would need the build user to have pacman rights.
        # `pacman -T` filters out deps already satisfied by an installed
        # package's provides, which `pacman -S` can't resolve.
        mapfile -t deps < <(build_deps "$src")
        missing_deps=()
        if ((${#deps[@]})); then
            mapfile -t missing_deps < <(pacman -T "${deps[@]}")
        fi
        if ((${#missing_deps[@]})) && ! timed "$name build deps" pacman_locked -S --needed --noconfirm "${missing_deps[@]}"; then
            echo "aur-sync: $name failed to install dependencies (${missing_deps[*]})" >&2
            failures+=("$name (dependency install failed)")
            continue
        fi

        if ! import_pgp_keys "$src"; then
            echo "aur-sync: $name failed to import required PGP key(s)" >&2
            failures+=("$name (PGP key import failed)")
            continue
        fi

        if [[ -z "$build_root_repo" ]]; then
            timed "create build user" ensure_build_user
            timed "install base-devel" ensure_makepkg_prereqs
            BUILD_ROOT="$(mktemp -d /var/tmp/sobarch-aur-sync-build.XXXXXX)"
            cleanup_paths+=("$BUILD_ROOT")
            build_root_repo="$BUILD_ROOT/repo"
            timed "copy repo tree" cp -a "$repo_dir" "$build_root_repo"
            timed "chown repo tree" chown -R "$BUILD_USER:$BUILD_USER" "$BUILD_ROOT"
        fi

        build_dir="$build_root_repo/${src#"$repo_dir"/}"

        if ! timed "$name makepkg" runuser -u "$BUILD_USER" -- bash -c "cd '$build_dir' && makepkg --noconfirm --needed --clean"; then
            echo "aur-sync: $name failed to build" >&2
            failures+=("$name (makepkg failed)")
            continue
        fi

        pkgfiles=("$build_dir"/*.pkg.tar.*)
    fi

    # The installer deploys this script unowned before sobarch-scripts
    # exists, so pacman must be allowed to overwrite that one file.
    overwrite_args=()
    if [[ "$name" == "sobarch-scripts" ]]; then
        overwrite_args=(--overwrite /usr/local/lib/sobarch/aur-sync.sh)
    fi

    # Skip snap-pac after the first install to avoid one snapshot pair
    # per package.
    if $first_install; then
        install_result=0
        timed "$name pacman -U" pacman_locked -U --noconfirm --ask=4 "${overwrite_args[@]}" "${pkgfiles[@]}" || install_result=$?
    else
        install_result=0
        SNAP_PAC_SKIP=1 timed "$name pacman -U" pacman_locked -U --noconfirm --ask=4 "${overwrite_args[@]}" "${pkgfiles[@]}" || install_result=$?
    fi

    [[ -n "$build_dir" ]] && rm -rf "$build_dir"

    if ((install_result != 0)); then
        echo "aur-sync: $name failed to install" >&2
        failures+=("$name (pacman -U failed)")
        continue
    fi

    first_install=false
    echo "aur-sync: $name installed ($pinned)."
done

if ((${#scope_failures[@]} + ${#failures[@]})); then
    # Repeated at the end so the verdict isn't lost in build noise.
    echo "aur-sync: run finished with failures:" >&2
    for name in "${scope_failures[@]}"; do
        echo "  $name (not vendored)" >&2
    done
    ((${#failures[@]})) && printf '  %s\n' "${failures[@]}" >&2

    if $notify_on_failure; then
        GLYPH=$'\U000F03D4'
        # shellcheck source=/dev/null
        source /usr/local/lib/sobarch/notify-user.sh
        notify_user critical "Package update failed" \
            "$(printf '%s\n' "${scope_failures[@]/%/ (not vendored)}" "${failures[@]}")" >/dev/null
    fi
    exit 1
fi

echo "aur-sync: run finished, nothing left to do."
