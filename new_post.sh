#!/bin/bash
# ====== Script Auto Tạo Writeup ======
# Usage: ./new-post.sh <Category> "<Title>"
# Ví dụ: ./new-post.sh HTB "Kenobi Machine"

if [ $# -lt 2 ]; then
  echo "❗ Dùng: $0 <Category> \"Title\""
  exit 1
fi

category_original="$1"
shift
title_original="$*"

# Xử lý tên an toàn
category_safe=$(echo "$category_original" | iconv -f UTF-8 -t ASCII//TRANSLIT | sed -r 's/[^A-Za-z0-9]+/_/g' | sed -r 's/^_+|_+$//g')
title_slug=$(echo "$title_original" | iconv -f UTF-8 -t ASCII//TRANSLIT | sed -r 's/[^A-Za-z0-9]+/-/g' | sed -r 's/^-+|-+$//g' | tr 'A-Z' 'a-z')

collection_dir="_${category_safe}"
layout_file="_layouts/${category_safe}.html"
page_file="${category_safe}.html"
today=$(date +%Y-%m-%d)
post_file="${collection_dir}/${today}-${title_slug}.md"

# ====== 1. Tạo collection folder ======
if [ ! -d "$collection_dir" ]; then
  mkdir "$collection_dir"
  echo "✅ Created collection folder: $collection_dir/"
fi

# ====== 2. Thêm config vào _config.yml ======
if ! grep -q "$category_safe:" _config.yml; then
  echo "Thêm collection vào _config.yml..."
  cat >> _config.yml <<EOF

collections:
  $category_safe:
    output: true
    permalink: /$category_safe/:title/
EOF
else
  echo "ℹ️ Collection '$category_safe' đã có trong _config.yml"
fi

# ====== 3. Tạo file writeup ======
if [ ! -f "$post_file" ]; then
  cat > "$post_file" <<EOF
---
layout: post
title: "$title_original"
date: $(date +%Y-%m-%d\ %H:%M:%S\ %z)
tags: [CTF, $category_original]
---

## Thông tin Challenge

## Phân tích

## Khai thác

## Flag

EOF
  echo "✅ Created writeup: $post_file"
else
  echo "⚠️ File $post_file đã tồn tại, bỏ qua."
fi

# ====== 4. Tạo layout HTML ======
if [ ! -f "$layout_file" ]; then
  cat > "$layout_file" <<EOF
---
layout: default
---

<h1>${category_original} Writeups</h1>
<ul>
{% for post in site.${category_safe} %}
  <li><a href="{{ post.url }}">{{ post.title }}</a> – {{ post.date | date: "%Y-%m-%d" }}</li>
{% endfor %}
</ul>
EOF
  echo "✅ Created layout file: $layout_file"
else
  echo "ℹ️ Layout file $layout_file đã tồn tại."
fi

# ====== 5. Tạo page hiển thị collection ======
if [ ! -f "$page_file" ]; then
  cat > "$page_file" <<EOF
---
layout: ${category_safe}
title: "${category_original} Writeups"
permalink: /${category_safe}/
---
EOF
  echo "✅ Created page: $page_file"
else
  echo "ℹ️ Page file $page_file đã tồn tại."
fi

# ====== 6. Add link vào menu ======
menu_file=""
if [ -f "_includes/nav.html" ]; then
  menu_file="_includes/nav.html"
elif [ -f "index.html" ]; then
  menu_file="index.html"
fi

if [ -n "$menu_file" ]; then
  if ! grep -q "${page_file}" "$menu_file"; then
    sed -i "/<\/ul>/ i\\
<li><a href=\"/${page_file}\">${category_original}</a></li>" "$menu_file"
    echo "✅ Added link to $category_original in $menu_file"
  else
    echo "ℹ️ Menu đã có mục $category_original."
  fi
else
  echo "⚠️ Không tìm thấy file nav.html hoặc index.html để thêm menu."
fi

echo "🎯 Hoàn tất! Bạn có thể sửa nội dung file: $post_file"
