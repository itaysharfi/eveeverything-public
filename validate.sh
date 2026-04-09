#!/bin/bash
# EVE-Everything Site Validation Script
# Run from project root: bash validate.sh

ERRORS=0
WARNINGS=0
DIR="$(cd "$(dirname "$0")" && pwd)"

red()    { printf "\033[31m%s\033[0m\n" "$1"; }
yellow() { printf "\033[33m%s\033[0m\n" "$1"; }
green()  { printf "\033[32m%s\033[0m\n" "$1"; }
bold()   { printf "\033[1m%s\033[0m\n" "$1"; }

error()   { red "  ERROR: $1"; ERRORS=$((ERRORS + 1)); }
warn()    { yellow "  WARN: $1"; WARNINGS=$((WARNINGS + 1)); }
pass()    { green "  PASS: $1"; }

bold "========================================"
bold "  EVE-Everything Site Validation"
bold "========================================"
echo ""

# ── 1. File structure ──
bold "1. File Structure"
for f in index.html workshop.html css/styles.css js/main.js; do
  if [ -f "$DIR/$f" ]; then
    pass "$f exists"
  else
    error "$f is missing"
  fi
done
echo ""

# ── 2. Image checks ──
bold "2. Images"
for img in images/logo.png images/heather_portrait_small.jpg images/heather-headshot.jpg images/favicon.png; do
  if [ -f "$DIR/$img" ]; then
    size=$(stat -f%z "$DIR/$img" 2>/dev/null || stat -c%s "$DIR/$img" 2>/dev/null)
    size_kb=$((size / 1024))
    if [ "$size_kb" -gt 500 ]; then
      warn "$img is ${size_kb}KB (consider compressing to < 500KB)"
    else
      pass "$img exists (${size_kb}KB)"
    fi
  else
    error "$img is missing"
  fi
done

# Check for WebP versions
for img in images/heather_portrait images/heather_portrait_small images/heather-headshot images/logo; do
  if [ -f "$DIR/${img}.webp" ]; then
    pass "${img}.webp exists"
  else
    warn "${img}.webp not found (add WebP for faster loading)"
  fi
done
echo ""

# ── 3. Link validation ──
bold "3. Internal Links"
for html in index.html workshop.html; do
  # Check href links to local files
  hrefs=$(grep -oE 'href="[^"#][^"]*"' "$DIR/$html" | grep -v 'mailto:' | grep -v 'tel:' | grep -v 'http' | sed 's/href="//;s/"//')
  for href in $hrefs; do
    target=$(echo "$href" | cut -d'#' -f1)
    if [ -n "$target" ] && [ ! -f "$DIR/$target" ]; then
      error "[$html] broken link: $href (file not found)"
    fi
  done

  # Check image src references
  srcs=$(grep -oE 'src="[^"]*"' "$DIR/$html" | sed 's/src="//;s/"//')
  for src in $srcs; do
    if [ ! -f "$DIR/$src" ]; then
      error "[$html] broken image: $src (file not found)"
    fi
  done
done
pass "Internal link check complete"
echo ""

# ── 4. Email domain ──
bold "4. Email Domain"
old_domain=$(grep -c 'eve-fertility.com' "$DIR/index.html" "$DIR/workshop.html" 2>/dev/null | grep -v ':0$')
if [ -n "$old_domain" ]; then
  error "Old domain 'eve-fertility.com' still found: $old_domain"
else
  pass "All emails use eveeverything.com"
fi
echo ""

# ── 5. Em-dash check ──
bold "5. Em-dash Check"
for html in index.html workshop.html; do
  emdash_count=$(grep -c '—' "$DIR/$html" 2>/dev/null)
  if [ "${emdash_count:-0}" -gt 0 ]; then
    warn "[$html] Found $emdash_count em-dash(es) in visible content"
    grep -n '—' "$DIR/$html" | head -5
  else
    pass "[$html] No em-dashes found"
  fi
done
echo ""

# ── 6. Navigation consistency ──
bold "6. Navigation Consistency"
for html in index.html workshop.html; do
  nav_items=$(grep -c 'class="nav-link' "$DIR/$html")
  mobile_items=$(grep -c 'class="mobile-nav-link' "$DIR/$html")
  if [ "$nav_items" -eq "$mobile_items" ]; then
    pass "[$html] Desktop nav ($nav_items items) matches mobile nav ($mobile_items items)"
  else
    error "[$html] Desktop nav ($nav_items) != mobile nav ($mobile_items)"
  fi
done

# Check no "Services" in nav
for html in index.html workshop.html; do
  services_nav=$(grep 'nav-link.*Services\|nav-link.*#services' "$DIR/$html" | wc -l | tr -d ' ')
  if [ "$services_nav" -gt 0 ]; then
    warn "[$html] 'Services' still in navigation (should be removed)"
  fi
done
pass "Navigation structure check complete"
echo ""

# ── 7. Copywriting & UX checks ──
bold "7. Copywriting & UX"
for html in index.html workshop.html; do
  # Missing alt text
  no_alt=$(grep '<img' "$DIR/$html" | grep -cv 'alt=')
  if [ "$no_alt" -gt 0 ]; then
    error "[$html] $no_alt image(s) missing alt text"
  else
    pass "[$html] All images have alt text"
  fi

  # Check for placeholder text
  placeholders=$(grep -ciE 'lorem ipsum|placeholder|TODO|FIXME|XXX' "$DIR/$html")
  if [ "${placeholders:-0}" -gt 0 ]; then
    error "[$html] Found placeholder text"
  else
    pass "[$html] No placeholder text"
  fi

  # Check page title exists
  has_title=$(grep -c '<title>' "$DIR/$html")
  if [ "$has_title" -gt 0 ]; then
    pass "[$html] Has page title"
  else
    error "[$html] Missing page title"
  fi

  # Check meta description
  has_desc=$(grep -c 'meta name="description"' "$DIR/$html")
  if [ "$has_desc" -gt 0 ]; then
    pass "[$html] Has meta description"
  else
    warn "[$html] Missing meta description"
  fi
done

# Principle of least surprise: mailto buttons should say "email"
for html in index.html workshop.html; do
  # Find buttons with mailto that don't mention "email" or "message"
  surprise_btns=$(grep 'mailto:' "$DIR/$html" | grep 'class="btn' | grep -ivE 'email|message' | wc -l | tr -d ' ')
  if [ "$surprise_btns" -gt 0 ]; then
    error "[$html] $surprise_btns mailto button(s) don't mention 'email' (surprises users)"
    grep 'mailto:' "$DIR/$html" | grep 'class="btn' | grep -ivE 'email|message'
  else
    pass "[$html] All mailto buttons clearly indicate email action"
  fi
done

# Check "Visit Us" doesn't appear (it's a PO Box)
for html in index.html workshop.html; do
  visit_us=$(grep -ci 'Visit Us\|Our Address' "$DIR/$html")
  if [ "${visit_us:-0}" -gt 0 ]; then
    # Only warn if it says "Visit Us" or "Our Address"
    visit_count=$(grep -ci 'Visit Us' "$DIR/$html")
    if [ "${visit_count:-0}" -gt 0 ]; then
      error "[$html] Says 'Visit Us' but address is a PO Box"
    fi
  fi
done
pass "PO Box address check complete"
echo ""

# ── 8. Mobile readiness ──
bold "8. Mobile Readiness"
for html in index.html workshop.html; do
  has_viewport=$(grep -c 'viewport' "$DIR/$html")
  if [ "$has_viewport" -gt 0 ]; then
    pass "[$html] Has viewport meta tag"
  else
    error "[$html] Missing viewport meta tag"
  fi
done

# Check CSS has responsive breakpoints
breakpoints=$(grep -c '@media' "$DIR/css/styles.css")
if [ "$breakpoints" -ge 3 ]; then
  pass "CSS has $breakpoints media queries"
else
  warn "CSS has only $breakpoints media queries (expected 3+)"
fi

# Check hamburger menu exists
has_hamburger=$(grep -c 'hamburger' "$DIR/css/styles.css")
if [ "$has_hamburger" -gt 0 ]; then
  pass "Mobile hamburger menu styles present"
else
  error "Missing mobile hamburger menu styles"
fi
echo ""

# ── 9. Performance ──
bold "9. Performance"
for html in index.html workshop.html; do
  external_css=$(grep -c 'link.*href="http' "$DIR/$html")
  external_js=$(grep -c 'script.*src="http' "$DIR/$html")
  if [ "$external_css" -gt 0 ] || [ "$external_js" -gt 0 ]; then
    warn "[$html] External CSS/JS resources found (affects loading speed)"
  else
    pass "[$html] No external CSS/JS dependencies"
  fi
done

# Check font preloading
for html in index.html workshop.html; do
  preloads=$(grep -c 'rel="preload".*font' "$DIR/$html")
  if [ "$preloads" -ge 2 ]; then
    pass "[$html] Fonts preloaded ($preloads)"
  else
    warn "[$html] Missing font preloads"
  fi
done

# Check for picture/webp usage in HTML
for html in index.html workshop.html; do
  img_count=$(grep -c '<img' "$DIR/$html")
  picture_count=$(grep -c '<picture>' "$DIR/$html")
  if [ "$picture_count" -gt 0 ]; then
    pass "[$html] Uses <picture> tags for WebP ($picture_count)"
  else
    warn "[$html] No <picture> tags found (add WebP with fallback)"
  fi
done

# Check sitemap and robots.txt
if [ -f "$DIR/sitemap.xml" ]; then
  pass "sitemap.xml exists"
else
  warn "sitemap.xml not found (needed for SEO)"
fi
if [ -f "$DIR/robots.txt" ]; then
  pass "robots.txt exists"
else
  warn "robots.txt not found"
fi

# Verify all image src/srcset in HTML point to existing files
for html in index.html workshop.html; do
  broken=0
  for img in $(grep -oE '(src|srcset)="images/[^"]*"' "$DIR/$html" | sed 's/.*"images/images/;s/"//'); do
    if [ ! -f "$DIR/$img" ]; then
      error "[$html] Missing image: $img"
      broken=$((broken + 1))
    fi
  done
  if [ "$broken" -eq 0 ]; then
    pass "[$html] All image files exist"
  fi
done

# Total CSS size
css_size=$(stat -f%z "$DIR/css/styles.css" 2>/dev/null || stat -c%s "$DIR/css/styles.css" 2>/dev/null)
css_kb=$((css_size / 1024))
if [ "$css_kb" -lt 50 ]; then
  pass "CSS is ${css_kb}KB (lightweight)"
else
  warn "CSS is ${css_kb}KB (consider minifying)"
fi
echo ""

# ── 10. Legal & Copyright ──
bold "10. Legal & Copyright"
current_year=$(date +%Y)

# Check copyright year is current
copyright_line=$(grep -i 'copyright\|©' "$DIR/index.html" | head -1)
if echo "$copyright_line" | grep -q "$current_year"; then
  pass "Copyright year is current ($current_year)"
elif echo "$copyright_line" | grep -qE '[0-9]{4}'; then
  found_year=$(echo "$copyright_line" | grep -oE '[0-9]{4}' | head -1)
  warn "Copyright year is $found_year (should be $current_year)"
else
  warn "No copyright year found"
fi

# Check disclaimer on both pages
for html in index.html workshop.html; do
  has_disclaimer=$(grep -c 'disclaimer' "$DIR/$html")
  if [ "$has_disclaimer" -gt 0 ]; then
    pass "[$html] Medical disclaimer present"
  else
    warn "[$html] Missing medical disclaimer"
  fi
done
echo ""

# ── Summary ──
bold "========================================"
if [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
  green "  ALL CHECKS PASSED"
elif [ "$ERRORS" -eq 0 ]; then
  yellow "  PASSED with $WARNINGS warning(s)"
else
  red "  FAILED: $ERRORS error(s), $WARNINGS warning(s)"
fi
bold "========================================"
exit $ERRORS
