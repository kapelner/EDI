#!/usr/bin/env bash
# Generate <site>/llms-full.txt for the pkgdown site: the ENTIRE built
# documentation -- every reference page and every article -- concatenated
# into one plain-text file, so an agent can ingest the whole package in a
# single fetch. This is the llms.txt convention's "full" variant; the short
# llms.txt (a hand-written summary + index, R/EDI/pkgdown/assets/llms.txt) is
# prepended so the file is self-describing.
#
# Until 2026-09-16 pkgdown/assets/llms-full.txt was a 6.5 KB hand-written
# prose file -- effectively a second llms.txt, not "full" at all. It is now
# a stub pointing here, and this script overwrites the copied stub in the
# built site with the real thing. Run AFTER pkgdown::build_site_github_pages()
# (see .github/workflows/pkgdown.yaml); reads only the built HTML, so it
# needs no R and no package install -- just pandoc, which the workflow
# already sets up.
#
# Usage: build_llms_full.sh <site_dir>     # e.g. R/EDI/docs
set -euo pipefail

site="${1:?usage: build_llms_full.sh <pkgdown site dir>}"
[ -d "$site/reference" ] || { echo "build_llms_full: $site/reference not found -- run pkgdown first" >&2; exit 1; }
command -v pandoc >/dev/null || { echo "build_llms_full: pandoc not on PATH" >&2; exit 1; }

out="$site/llms-full.txt"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

# pandoc HTML -> plain text. --wrap=none keeps one logical line per
# paragraph (agents tokenize better without hard wraps); the Lua filter
# drops pkgdown's navigation/footer chrome, which is repeated identically on
# every page and would otherwise be ~30% of the output.
strip_chrome="$(mktemp --suffix=.lua)"
trap 'rm -f "$tmp" "$strip_chrome"' EXIT
cat > "$strip_chrome" <<'LUA'
-- Remove pkgdown nav/footer/sidebar containers by class or element.
function Div(el)
  for _, c in ipairs(el.classes) do
    if c == "navbar" or c == "pkgdown-footer" or c == "col-md-3" or c == "sidebar" or c == "dropdown" then
      return {}
    end
  end
  return nil
end
LUA

to_text() {
  pandoc "$1" -f html -t plain --wrap=none --lua-filter="$strip_chrome" 2>/dev/null
}

{
  if [ -f "$site/llms.txt" ]; then
    cat "$site/llms.txt"
  fi
  printf '\n\n%s\n' "=================================================================="
  printf '%s\n' "FULL DOCUMENTATION"
  printf '%s\n' "Generated $(date -u '+%Y-%m-%d %H:%M UTC') from the built pkgdown site by"
  printf '%s\n' ".github/scripts/build_llms_full.sh. Every article, then every reference"
  printf '%s\n' "page (design classes, inference classes, kernels, utilities), in the"
  printf '%s\n' "order the site's index lists them. Source: https://github.com/kapelner/EDI"
  printf '%s\n\n' "=================================================================="

  printf '%s\n\n' "################ ARTICLES ################"
  for f in "$site"/articles/*.html; do
    [ -f "$f" ] || continue
    case "$(basename "$f")" in index.html) continue ;; esac
    printf '\n\n======== ARTICLE: %s ========\n\n' "$(basename "$f" .html)"
    to_text "$f"
  done

  printf '\n\n%s\n\n' "################ REFERENCE ################"
  for f in "$site"/reference/*.html; do
    [ -f "$f" ] || continue
    case "$(basename "$f")" in index.html) continue ;; esac
    printf '\n\n======== REFERENCE: %s ========\n\n' "$(basename "$f" .html)"
    to_text "$f"
  done
} > "$tmp"

mv "$tmp" "$out"
n_ref=$(ls "$site"/reference/*.html 2>/dev/null | grep -vc '/index\.html$' || true)
n_art=$(ls "$site"/articles/*.html 2>/dev/null | grep -vc '/index\.html$' || true)
echo "build_llms_full: wrote $out ($(wc -c < "$out") bytes; $n_art articles, $n_ref reference pages)"
